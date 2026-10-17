"""
Unified CLI for query_app research tools.

Subcommands:
  oracle query   -- run a SELECT against HIS Oracle DB
  oracle schema  -- list tables/columns in a schema
  pcap oracle    -- extract Oracle TNS payloads from a pcapng file (requires tshark)
  decode infstarter -- decode infstarter:// payload (wraps decode_infstarter.py)

Usage:
    python src/cli.py oracle query --node he --sql "SELECT * FROM EXAM.PTEXAM WHERE REF_NO = :ref" --ref T0000000001
    python src/cli.py oracle schema --node he --schema EXAM
    python src/cli.py pcap oracle path/to/net_his.pcapng
    python src/cli.py decode infstarter "eJyF..."
"""
import argparse
import subprocess
import sys
from pathlib import Path

# Oracle DB nodes
NODES = {
    "ho": {"host": "10.0.0.1", "sid": "ho", "desc": "Operations/Demographics"},
    "he": {"host": "10.0.0.1", "sid": "he", "desc": "Clinical reports (EXAM/LAB/XRAY)"},
    "hi": {"host": "10.0.0.1", "sid": "hi", "desc": "Clinical history/indications"},
    "hi2": {"host": "10.0.0.1", "sid": "hi", "desc": "Config/master data"},
    "hb": {"host": "10.0.0.1", "sid": "hb", "desc": "Billing"},
}
DB_USER = "MOCK_USER"
DB_PASS = "MOCK_PASSWORD"
INSTANT_CLIENT = r"C:\instantclient_12_2"


def get_conn(node_key: str):
    import oracledb
    oracledb.init_oracle_client(lib_dir=INSTANT_CLIENT)
    node = NODES[node_key]
    dsn = f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={node['host']})(PORT=1521))(CONNECT_DATA=(SID={node['sid']})))"
    return oracledb.connect(user=DB_USER, password=DB_PASS, dsn=dsn)


def cmd_oracle_query(args):
    bind_vars = {}
    for b in (args.bind or []):
        k, v = b.split("=", 1)
        bind_vars[k] = v

    try:
        conn = get_conn(args.node)
    except Exception as e:
        print(f"Connection to {args.node} failed: {e}", file=sys.stderr)
        sys.exit(1)

    with conn:
        cur = conn.cursor()
        cur.execute(args.sql, bind_vars)
        cols = [d[0] for d in cur.description]
        rows = cur.fetchmany(args.limit)
        print("\t".join(cols))
        print("-" * 60)
        for row in rows:
            print("\t".join(str(v) if v is not None else "" for v in row))
        print(f"\n({len(rows)} rows)")


def cmd_oracle_schema(args):
    sql = """
        SELECT table_name, column_name, data_type, nullable
        FROM all_tab_columns
        WHERE owner = :schema
        ORDER BY table_name, column_id
    """
    try:
        conn = get_conn(args.node)
    except Exception as e:
        print(f"Connection to {args.node} failed: {e}", file=sys.stderr)
        sys.exit(1)

    with conn:
        cur = conn.cursor()
        cur.execute(sql, {"schema": args.schema.upper()})
        rows = cur.fetchall()
        current_table = None
        for table, col, dtype, nullable in rows:
            if table != current_table:
                print(f"\n{args.schema.upper()}.{table}")
                current_table = table
            print(f"  {col:<30} {dtype:<20} {'NULL' if nullable == 'Y' else 'NOT NULL'}")


def cmd_pcap_oracle(args):
    tshark = r"C:\Program Files\Wireshark\tshark.exe"
    pcap = Path(args.pcapng)
    if not pcap.exists():
        print(f"File not found: {pcap}", file=sys.stderr)
        sys.exit(1)

    cmd = [
        tshark, "-r", str(pcap),
        "-Y", "tcp.port == 1521 and data.len > 0",
        "-T", "fields",
        "-e", "frame.time_relative",
        "-e", "ip.src", "-e", "ip.dst",
        "-e", "tcp.len",
        "-e", "data.text",
    ]
    print(f"Extracting Oracle TNS payloads from {pcap.name} ...")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        for line in result.stdout.splitlines():
            parts = line.split("\t")
            if len(parts) >= 5 and parts[4].strip():
                t, src, dst, length, text = parts[0], parts[1], parts[2], parts[3], parts[4]
                print(f"[{t:>10}s] {src} → {dst} ({length} bytes): {text[:200]}")
    except FileNotFoundError:
        print(f"tshark not found at {tshark}. Install Wireshark.", file=sys.stderr)
        sys.exit(1)


def cmd_decode_infstarter(args):
    script = Path(__file__).parent / "decode_infstarter.py"
    subprocess.run([sys.executable, str(script)] + args.payload, check=False)


def main():
    parser = argparse.ArgumentParser(description="query_app research CLI")
    sub = parser.add_subparsers(dest="command")

    # oracle
    p_oracle = sub.add_parser("oracle", help="Oracle DB operations")
    oracle_sub = p_oracle.add_subparsers(dest="oracle_cmd")

    p_oq = oracle_sub.add_parser("query", help="Run a SELECT query")
    p_oq.add_argument("--node", choices=list(NODES), default="he",
                      help="DB node (default: he = EXAM/LAB/XRAY)")
    p_oq.add_argument("--sql", required=True, help="SQL query (use :name for bind vars)")
    p_oq.add_argument("--bind", "-b", action="append", metavar="KEY=VALUE",
                      help="Bind variable (can repeat)")
    p_oq.add_argument("--limit", type=int, default=50, help="Max rows (default 50)")

    p_os = oracle_sub.add_parser("schema", help="List tables/columns in a schema")
    p_os.add_argument("--node", choices=list(NODES), default="he")
    p_os.add_argument("--schema", required=True, help="Schema name (e.g. EXAM, LAB, XRAY, MAST)")

    # pcap
    p_pcap = sub.add_parser("pcap", help="Network capture analysis")
    pcap_sub = p_pcap.add_subparsers(dest="pcap_cmd")

    p_po = pcap_sub.add_parser("oracle", help="Extract Oracle TNS payloads")
    p_po.add_argument("pcapng", help="Path to .pcapng file")

    # decode
    p_decode = sub.add_parser("decode", help="Decode encoded payloads")
    decode_sub = p_decode.add_subparsers(dest="decode_cmd")

    p_di = decode_sub.add_parser("infstarter", help="Decode infstarter:// payload")
    p_di.add_argument("payload", nargs="+", help="Payload string(s)")

    args = parser.parse_args()

    if args.command == "oracle":
        if args.oracle_cmd == "query":
            cmd_oracle_query(args)
        elif args.oracle_cmd == "schema":
            cmd_oracle_schema(args)
        else:
            p_oracle.print_help()
    elif args.command == "pcap":
        if args.pcap_cmd == "oracle":
            cmd_pcap_oracle(args)
        else:
            p_pcap.print_help()
    elif args.command == "decode":
        if args.decode_cmd == "infstarter":
            cmd_decode_infstarter(args)
        else:
            p_decode.print_help()
    else:
        parser.print_help()
        print("\nDB nodes:")
        for k, v in NODES.items():
            print(f"  {k:<5} {v['host']}  {v['desc']}")


if __name__ == "__main__":
    main()
