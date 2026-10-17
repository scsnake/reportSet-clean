"""
Decode an infstarter:// payload from INFINITT PACS launcher.

The payload is the base64+zlib-encoded study parameters passed from the
RIS openimg.jsp page to Starter.exe (C:\ProgramData\infstarter\Starter.exe)
via the custom URI scheme: infstarter:///?su=<payload>

Usage:
    python decode_infstarter.py "eJyFkcts..."
    python decode_infstarter.py "infstarter:///?su=eJyFkcts..."
    python decode_infstarter.py "http://10.0.0.1:9090/webcvis/MJB/openimg.jsp?imgurl=..."
"""
import sys
import zlib
import base64
import urllib.parse
import argparse


def extract_payload(raw: str) -> str:
    raw = raw.strip()
    if "infstarter://" in raw:
        if "?su=" in raw:
            raw = raw.split("?su=")[1].split("&")[0]
        else:
            raw = raw.split("infstarter:///")[1]
    elif "imgurl=" in raw:
        # double-URL-encoded path: extract the infstarter arg from G3Launcher cmdline
        imgurl = urllib.parse.unquote(urllib.parse.unquote(raw.split("imgurl=")[1].split("&")[0]))
        parts = imgurl.split("+")
        # fields: exe, pacs_server, user_id, password, unknown, modality, study_id, ...
        if len(parts) >= 2:
            print(f"[G3Launcher cmdline decoded]")
            labels = ["exe", "pacs_server", "user_id", "password", "field4", "modality", "study_id"]
            for i, part in enumerate(parts):
                label = labels[i] if i < len(labels) else f"field{i}"
                print(f"  {label}: {part}")
        return ""
    return raw.strip()


def decode(payload: str) -> str:
    data = base64.b64decode(payload + "==")  # pad for safety
    return zlib.decompress(data).decode("utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser(
        description="Decode infstarter:// or G3Launcher imgurl payload",
        epilog="Example: python decode_infstarter.py 'infstarter:///?su=eJyF...'",
    )
    parser.add_argument("payload", help="Base64+zlib payload, infstarter:// URL, or openimg.jsp imgurl")
    args = parser.parse_args()

    payload = extract_payload(args.payload)
    if not payload:
        return

    try:
        result = decode(payload)
        print("[Decoded infstarter payload]")
        print(result)
        # Parse + fields if present
        if "+" in result:
            print("\n[Fields (+delimited)]")
            labels = ["pacs_server", "user_id", "password", "field3", "modality", "study_id"]
            for i, part in enumerate(result.split("+")):
                label = labels[i] if i < len(labels) else f"field{i}"
                print(f"  {label}: {part}")
    except Exception as e:
        print(f"Error decoding: {e}", file=sys.stderr)
        print(f"Raw payload: {payload}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
