#include <_RemoteBuf>
#include <SCI>
#include <CharWordPos>

;~ controlget,hwnd,hwnd,,Scintilla1,8-lex
;~ controlget,hwnd,hwnd,,Scintilla1,simple RIS
;~ rs:=new RemoteScintilla(hwnd)
    

;~ Loop 
;~ {
    ;~ ToolTip % rs.GetText()
;~ }


;~ return 

;~ esc::
;~ ExitApp
;~ return
;~ MsgBox % rs.GetText2()
;~ MsgBox % rs.GetLine(2)
;~ ExitApp
;~ ToolTip % rs.SetText("test測試")
;~ Sleep 1000
;~ exitapp
;~ return

;~ a:=new RemoteScintilla(getFocusedHwnd())
;~ a.SetCodePage(65001)
;~ MsgBox % a.GetCodePage()
;~ ExitApp

class RemoteScintilla {
    __New(hwnd){
        this.hwnd:=hwnd
        ,this.Buf:=new _RemoteBuf(this.hwnd)
        
    }
    

    GetText() { ; SCI_GETLENGTH := 2006, SCI_GETTEXT := 2182
        if(len:=this.GetTextLength())>0{
            Buf:=new _RemoteBuf(this.hwnd,len+1)
            ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GETTEXT,"UPTR",Buf.size,"PTR",Buf.RemoteBuf, "Ptr")
            ,Buf.Read()
            Return StrGet(Buf.LocalBuf,"UTF-8")
        }else{
            return ""
        }
    }
    SetText(Text){
        if(Text="")
            return this.ClearAll()
        else{
            ret:=StrPutVar(Text,str:="", "UTF-8")
            ,Buf:= new _RemoteBuf(this.hwnd, ret)
            ,Buf.Write(str,0,"UTF-8")
            ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SETTEXT,"PTR",0,"PTR",Buf.RemoteBuf, "Ptr")
            
            return ret
        }
    }
    InsertText(Text, pos=-1){
        if(Text="")
            return -1
        ret:=StrPutVar(Text,str:="", "UTF-8")
        ,Buf:= new _RemoteBuf(this.hwnd, ret)
        ,Buf.Write(str,0,"UTF-8")
        ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_INSERTTEXT,"PTR",pos,"PTR",Buf.RemoteBuf, "Ptr")
        
    }
    _InsertText(Text, pos=-1){
        if(Text="")
            return -1
        WordToCharPos(oldText:=this.GetText(), pos=-1?(pos:=StrLen(oldText)):pos)
        ,ret:=StrPutVar(Text,str:="", "UTF-8")
        ,Buf:= new _RemoteBuf(this.hwnd, ret)
        ,Buf.Write(str,0,"UTF-8")
        ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_INSERTTEXT,"PTR",pos,"PTR",Buf.RemoteBuf, "Ptr")
        
    }
    AddText(Text){ ;current position, move caret
        if(Text="")
            return -1
        if (ret:=StrPutVar(Text,str:="", "UTF-8")){
            Buf:= new _RemoteBuf(this.hwnd, ret)
            ,Buf.Write(str,0,"UTF-8")
            ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_ADDTEXT,"PTR",ret-1,"PTR",Buf.RemoteBuf, "Ptr")
        }
        
    }

    ReplaceSel(Text){
        ret:=StrPutVar(Text,str:="", "UTF-8")
        ,Buf:=new _RemoteBuf(this.hwnd, ret)
        ,Buf.Write(str,0,"UTF-8")
        return DllCall("SendMessage","PTR",this.hwnd,"UINT",SCI_REPLACESEL,"PTR",0,"PTR",Buf.RemoteBuf,"Ptr")
    }
    
    DeleteRange(pos, len){
         if pos<0
            pos:=0, 
            ,len-= abs(pos)
        if len<0
            return
    
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_DELETERANGE,"PTR", pos,"PTR", len, "PTR")
    }
    
    _DeleteRange(pos, len, Text=""){
        if Text=
            Text:=this.GetText()
        
        WordToCharPos(Text, s:=pos, e:=pos+len)
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_DELETERANGE,"PTR", s,"PTR", e-s, "PTR")
    }
    
    GetSelectionStart(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GETSELECTIONSTART,"PTR",0,"PTR",0,"PTR")
    }
    GetSelectionEnd(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GETSELECTIONEND,"PTR",0,"PTR",0,"PTR")
    }
    GetCurrentPos(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetCurrentPos,"PTR",0,"PTR",0,"PTR")
    }
    GetAnchor(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetAnchor,"PTR",0,"PTR",0,"PTR")
    }
    GetLineCount(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GETLINECOUNT,"PTR",0,"PTR",0,"PTR")
    }
    GetSel(ByRef s="", ByRef e="", Text=""){
        if Text=
            Text:=this.GetText()
        
        s:=this.GetAnchor(Text)
        ,e:=this.GetCurrentPos(Text)
        return {start:s, End:e}
    }
    
    _GetSelectionStart(Text=""){
        ;~ if Strlen(Text:=this.GetText())!=(l:=this.GetLength()){
            ;~ return this.GetSelectionStart()
        ;~ }
        if Text=
            Text:=this.GetText()
        s:=DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GETSELECTIONSTART,"PTR",0,"PTR",0,"PTR")
        ,CharToWordPos(Text, s)
        return s
    }
    _GetSelectionEnd(Text=""){
        ;~ if Strlen(Text:=this.GetText())!=(l:=this.GetLength()){
            ;~ return this.GetSelectionEnd()
        ;~ }
        if Text=
            Text:=this.GetText()
        e:=DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GETSELECTIONEND,"PTR",0,"PTR",0,"PTR")
        ,CharToWordPos(Text, e)
        return e
    }
    _GetCurrentPos(Text=""){
        ;~ if Strlen(Text:=this.GetText())!=(l:=this.GetLength()){
            ;~ return this.GetCurrentPos()
        ;~ }
        if Text=
            Text:=this.GetText()
        s:=DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetCurrentPos,"PTR",0,"PTR",0,"PTR")
        ,CharToWordPos(Text, s)
        return s
    }
    _GetAnchor(Text=""){
        ;~ if Strlen(Text:=this.GetText())!=(l:=this.GetLength()){
            ;~ return this.GetAnchor()
        ;~ }
        if Text=
            Text:=this.GetText()
        e:=DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetAnchor,"PTR",0,"PTR",0,"PTR")
        ,CharToWordPos(Text, e)
        return e
    }
    _GetSel(ByRef s="", ByRef e="", Text=""){
        ;~ if Strlen(Text:=this.GetText())!=(l:=this.GetLength()){
            ;~ return this.GetSel()
        ;~ }
        if Text=
            Text:=this.GetText()
        
        s:=this.GetAnchor(Text)
        ,e:=this.GetCurrentPos(Text)
        ,CharToWordPos(Text, s, e)
        return {start:s, End:e}
    }
    
    GetSelWords(Text=""){
        if Text=
            Text:=this.GetText()
        
        if(len:=this.GetTextLength())>0 {
            s0:=s:=this.GetSelectionStart(Text)
            ,e0:=e:=this.GetSelectionEnd(Text)
            ,s:=DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_WORDSTARTPOSITION,"PTR",s, "INT",1 ,"PTR")
            ,e:=DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_WORDENDPOSITION,"PTR",e,"INT",1,"PTR")
            if(s!=s0)
                this.SetSelectionStart(s, Text)
            if(e!=e0)
                this.SetSelectionEnd(e, Text)
            return this.GetSelText()
        }else{
            return ""
        }
    }
    
    GetSelText(){
        if(len:=this.GetTextLength())>0 {
            Buf:=new _RemoteBuf(this.hwnd,this.GetTextLength()+4)
            ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetSelText,"UPTR",Buf.size,"PTR",Buf.RemoteBuf, "Ptr")
            ,Buf.Read()
            Return StrGet(Buf.LocalBuf,"UTF-8")
        }else{
            return ""
        }
    }
    
    StyleGetFont(styleNumber){
        Buf:=new _RemoteBuf(this.hwnd,32)
        ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_StyleGetFont,"UPTR",styleNumber,"PTR",Buf.RemoteBuf, "Ptr")
        ,Buf.Read()
        Return StrGet(Buf.LocalBuf,"UTF-8")
      
    }
    
    GetLine(line=""){
        if(line="" || line=-1)
            line:=this.LINEFROMPOSITION()
        Buf:=new _RemoteBuf(this.hwnd,this.LineLength(line)+1)
        ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetLine,"PTR",line,"PTR",Buf.RemoteBuf, "Ptr")
        ,Buf.Read()
        Return StrGet(Buf.LocalBuf,"UTF-8")
    }
    
    ;~ GetStyleAt(Pos){
        ;~ Buf:=new _RemoteBuf(this.hwnd,32)
        ;~ ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetStyleAt,"PTR", pos,"PTR",Buf.RemoteBuf, "Ptr")
        ;~ ,Buf.Read()
        ;~ Return StrGet(Buf.LocalBuf,"UTF-8")
    ;~ }
    
    ;~ GetCharAt(Pos){
        ;~ Buf:=new _RemoteBuf(this.hwnd,32)
        ;~ ,DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetCharAt,"PTR", pos,"PTR",Buf.RemoteBuf, "Ptr")
        ;~ ,Buf.Read()
        ;~ Return StrGet(Buf.LocalBuf,"UTF-8")
    ;~ }
    
    LineLength(line=""){
        if(line="" || line=-1)
            line:=this.LineFromPosition()
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_LineLength,"PTR",line,"PTR",0,"PTR")
    }
    LineFromPosition(pos=""){
        if(pos="")
            pos:=this.GetCurrentPos()
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_LINEFROMPOSITION,"PTR",pos,"PTR",0,"PTR")
    }
    
    
    SetSelectionStart(s){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetSELECTIONSTART,"PTR",s,"PTR",0,"PTR")
    }
    SetSelectionEnd(e){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetSELECTIONEND,"PTR",e,"PTR",0,"PTR")
    }
    SetCurrentPos(s){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetCurrentPos,"PTR",s,"PTR",0,"PTR")
    }
    SetAnchor(e){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetAnchor,"PTR",e,"PTR",0,"PTR")
    }
    SetSel(s="", e=""){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetSel,"PTR",s,"PTR",e, "PTR")
    }
    
    
    _SetSelectionStart(s, Text=""){
        if Text=
            Text:=this.GetText()
        
        if Strlen(Text)=(l:=this.GetLength()){
            s:=(s=-1)?l:s
            return this.SetSelectionStart(s, Text)
        }
        WordToCharPos(Text, s)
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetSELECTIONSTART,"PTR",s,"PTR",0,"PTR")
    }
    _SetSelectionEnd(e, Text=""){
        if Text=
            Text:=this.GetText()
        
        if Strlen(Text)=(l:=this.GetLength()){
            e:=(e=-1)?l:e
            return this.SetSelectionEnd(e, Text)
        }
        WordToCharPos(Text, e)
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetSELECTIONEND,"PTR",e,"PTR",0,"PTR")
    }
    _SetCurrentPos(s, Text=""){
        if Text=
            Text:=this.GetText()
        
        if Strlen(Text)=(l:=this.GetLength()){
            s:=(s=-1)?l:s
            return this.SetCurrentPos(s, Text)
        }
        WordToCharPos(Text, s)
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetCurrentPos,"PTR",s,"PTR",0,"PTR")
    }
    _SetAnchor(e, Text=""){
        if Text=
            Text:=this.GetText()
        
        if Strlen(Text)=(l:=this.GetLength()){
            e:=(e=-1)?l:e
            return this.SetAnchor(e, Text)
        }
        WordToCharPos(Text, e)
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetAnchor,"PTR",e,"PTR",0,"PTR")
    }
    _SetSel(s="", e="", Text=""){
        if Text=
            Text:=this.GetText()
        
        if Strlen(Text)=(l:=(l:=this.GetLength())) {
            s:=(s=-1)?l:s, e:=(e=-1)?l:e
            return this.SetSel(s,e, Text)
        }
        WordToCharPos(Text, s, e)
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetSel,"PTR",s,"PTR",e, "PTR")
    }
    LINESCROLL(columns, Lines){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_LINESCROLL,"PTR",columns,"PTR",Lines, "PTR")
    }
    
    SelAll(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SELECTALL,"PTR",0,"PTR",0,"PTR")
    }   
    
    GetLength(){
        return this.GetTextLength()
    }
    GetTextLength(){
        Return DllCall("SendMessage","PTR",this.hwnd,"UInt",SCI_GETTEXTLENGTH,"PTR",0,"PTR",0,"PTR")
    }
    ScrollCaret(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_ScrollCaret,"PTR",0,"PTR",0,"PTR")
    }
    ScrollRange(secondary="", primary=""){
        this.GetSel(s, e)
        if(primary="")
            primary:=e
        if(secondary="")
            secondary:=s
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_ScrollRange,"PTR",secondary, "PTR", primary,"PTR")
    }
    ClearAll(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_ClearAll,"PTR",0,"PTR",0,"PTR")
    }
    
    SetCodePage(code){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetCodePage,"PTR",code,"PTR",0,"PTR")
    }
    GetCodePage(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetCodePage,"PTR",0,"PTR",0,"PTR")
    }
    SetCaretStyle(style){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_SetCaretStyle,"PTR",style,"PTR",0,"PTR")
    }
    GetCaretStyle(){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT", SCI_GetCaretStyle,"PTR",0,"PTR",0,"PTR")
    }
    DelLine(to=""){
        return DllCall("SendMessage","PTR",this.hwnd,"UINT",to=""?SCI_LINEDELETE:(to="left"? SCI_DELLINELEFT : SCI_DELLINERIGHT),"PTR",0,"PTR",0,"PTR")
    }
    
    
    Do(command){
        if command is not integer
        {
            ;~ if InStr(command, "_GET")
                ;~ getCommand:=true
            command:=%command%
        }
        
        
            try
                ret:= DllCall("SendMessage","PTR",this.hwnd,"UINT", command,"PTR", 0,"PTR",0, "PTR")
            return ret

    }
}
