
;~ a:=new DataGridTable([[1,2,3,4], [5,6,7,8]])
;~ for k,v in a
	;~ MsgBox % k
;~ a:=ParseDataGrid2()	
;~ MsgBox % exploreobj(a.collectSameStudy())
;~ ExitApp
class DataGridTable {
	__New(ByRef data){
		global __is_CH
		this.titles:=data[1]
		,this.colNos:=[]
		,this.data:=data
		,thisPlace:=getPlace()
		for k,v in this.titles
			if (v!="")
				this.colNos[v]:=k
		
		if ! this.colNos["AccNo"]
			this.colNos["AccNo"]:=__is_CH?this.colNos["開單序號"]:this.colNos["照會單號"]
		if ! this.colNos["ChartNo"]
			this.colNos["ChartNo"]:=this.colNos["病歷號"]
		if ! this.colNos["ExamName"]
			this.colNos["ExamName"]:=__is_CH?this.colNos["檢查項目"]:this.colNos["檢查名稱"]
		if ! this.colNos["Status"]
			this.colNos["Status"]:=this.colNos["狀態"]
		if ! this.colNos["ExamDate"]
			this.colNos["ExamDate"]:=__is_CH?this.colNos["檢查日期"]:this.colNos["檢查日"]
		if ! this.colNos["ReportVS"]
			this.colNos["ReportVS"]:=this.colNos["報告醫師"]
		if ! this.colNos["EIO"]
			this.colNos["PatientSource"]:=this.colNos["EIO"]:=__is_CH?this.colNos["來源"]:this.colNos["診別"]
		if  ! this.colNos["PatientName"]
			this.colNos["PatientName"]:=this.colNos["姓名"]
		if  ! this.colNos["ExamType"]
			this.colNos["ExamType"]:=this.colNos["檢查種類"]
		if  ! this.colNos["PatientAge"]
			this.colNos["PatientAge"]:=this.colNos["年齡"]
		
		if  ! this.colNos["reportOwner"]
			this.colNos["reportOwner"]:=this.colNos["擁有者"]
		if  ! this.colNos["reportVS"]
			this.colNos["reportVS"]:=this.colNos["報告醫師"]
		if  ! this.colNos["reportDate"]
			this.colNos["reportDate"]:=this.colNos["報告日期"]
		if  ! this.colNos["hospitalBranch"]
			this.colNos["hospitalBranch"]:=this.colNos["院區"]
		
		
		AccNoCol:=this.colNos["AccNo"]
		
		,ind:={}
		for k,v in data
			if (k>1 && (accno:=v[AccNoCol])!="")
				ind[accno]:=k
		this.__accno_index:=ind		
		
		,data.base:=this
		
		
		
		return data
	}
	
	_NewEnum(){
		this.enum_ind:=0
		,this.data_ind_max:=this.data.maxIndex()
		return this
	}
	
	getSameStudy(AccNo){
		if AccNo=
			return []
		row:=this.getRow("AccNo", accNo)
		if !(row.rowNo)
			return []
		chartNo:=row.getCell("ChartNo")
		,examDate:=row.getCell("ExamDate")
		,res:=this.getRowsByVal("ExamDate", examDate)
		,ret:=[]
		for k,v in res {
			if (v.getCell("ChartNo")=chartNo)
				ret[k]:=v
		}
		return ret
	}
	
	collectSameStudy(){
		static cols:="examDate,chartNo,accNo"
		ret1:=[]
		,ret2:=[]
		,ret:=[]
		loop,parse,cols,`,
			%a_loopfield%col:=this.colNos[A_LoopField]
		for k,v in this.data {
			if k=1
				continue
			loop,parse,cols,`,
				%a_loopfield%:=v[%a_loopfield%col]
			if !(ret1.haskey(key:=examDate "|" chartNo))
				ret1[key]:=[]
			ret1[key].push(new this.DataGridRow(v, this.colNos, k))
			,ret2.push(key)
		}
		for k,v in ret2 {
			RegExMatch(v, "^([^\|]+)\|([^\|]+)$", m)
			st:=[]
			,st["ChartNo"]:=m2
			,st["ExamDate"]:=m1
			,st["Rows"]:=ret1[v]
			,st["AccNo"]:=[]
			for x,y in st.Rows
				st["AccNo"].push(y[AccNoCol])
			ret.push(st)
		}
		return ret
	}
	
	Next(ByRef k, ByRef v){
		k:=++this.enum_ind
		,v:=new this.base.base.DataGridRow(this.base.data[k], this.base.colNos, k)
		return k<=this.data_ind_max
	}
		
	class DataGridRow {
		__New(ByRef data, colNos, rowNo){
			this.colNos:=colNos
			,this.data:=data
			,this.rowNo:=rowNo
			,data.base:=this
			return data
		}
		getColNo(colName){
			return this.colNos[colName]
		}
		getCell(colName){
			return this.data[this.getColNo(colName)]
		}
	}
	
	getColNo(colName){
		return this.colNos[colName]
	}
	
	getCell(row, colName){
		return this.data[row][this.getColNo(colName)]
	}
	
	getRow(rowOrColName, value=""){
		if (value!="")
			return this.getRowByVal(rowOrColName, value)
		else
			return (r:=this.data[rowOrColName])?new this.DataGridRow(r, this.colNos, rowOrColName):""
		
	}

	
	getRowByVal(colName, value){
		if (colName="AccNo" || colName="照會單號") && (this.__accno_index.haskey(value))
			return new this.DataGridRow(this.data[k:=this.__accno_index[value]], this.colNos, k)
		
		col:=this.getColNo(colName)
		for k,v in this.data {
			if (v[col]=value) && (k!=1){
				return new this.DataGridRow(v, this.colNos, k)
			}
		}
	}
	
	getRowsByVal(colName, value){
		col:=this.getColNo(colName)
		,ret:=[]
		for k,v in this.data {
			if (v[col]=value) && (k!=1){
				ret[k]:=new this.DataGridRow(v, this.colNos, k)
			}
		}
		return ret
	}
}

