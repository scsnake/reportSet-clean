; ==============================================================================
; Library: _RemoteBuf.ahk
; Classification: Pure Third-Party
; Original Author: HotKeyIt
; Origin: AutoHotkey Forum (_RemoteBuf)
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/board/topic/69202-remotebuf/
; ==============================================================================

; Remote Buffer Class, thanks to majkinetor for RemoteBuf() http://www.autohotkey.com/community/viewtopic.php?f=2&t=12251

; Don't forget to #include <_RemoteBuf> in your script.

; - How Create new Remote Buffer
;    Buffer := new _RemoteBuf(WindowOrControlHandle,SizeOfRemoteBuffer:=0)
; - How to read buffer
;    Buffer.Read([BytesToRead])
; - How to write buffer
;    Buffer.Write(StringOrBuffer[,Offset=0,Encoding:="CP0"]) ; Encoding = same values as used by StrPut
;    Buffer.NumPut(Number[,Offset=0,Type:="UInt"]) ; Type = same values as used by NumPut
; - How to free buffer
;    Buffer:=""

Class _RemoteBuf {
	pid:=0,RemoteBuf:=0,size:=0,hProc:=0,LocalBuf:=0,Encoding:="UTF-8"
	__New(hwnd,size=0){
		this.Open(size,hwnd) ; open remote buffer
	}
	__Delete(){ ; delete memory used by remote buffer when it gets released
		static MEM_RELEASE:=0x8000
		If !this.hProc ; no process open = no memory allocated
			Return
		If this.RemoteBuf ; only free if buffer exists
			If !DllCall("VirtualFreeEx","PTR",this.hProc,"PTR",this.RemoteBuf,"PTR",0,"uint",MEM_RELEASE)
				return DllCall("MessageBox","PTR",0,"Str","Unable to free memory (" A_LastError ")","Str","OpenProcess Failed","UInt",0)
		DllCall( "CloseHandle", "PTR", this.hProc) ;close remote buffer handle
	}
	Open(size="",hwnd=0){ ; opens new remote buffer
		static MEM_COMMIT:=0x1000,PAGE_READWRITE:=4,MEM_RELEASE:=0x8000
		If (!this.hProc||hwnd) { ; no buffer opened yet or new handle specified
			If this.RemoteBuf ; we have a new handle and need to delete old buffer
				DllCall("VirtualFreeEx","PTR",this.hProc,"PTR",this.RemoteBuf,"PTR",0,"uint",MEM_RELEASE)
			If this.hProc ; we have a new handle, close process
				DllCall( "CloseHandle", "PTR", this.hProc)
			DetectHiddenWindows % DetectHidden:=A_DetectHiddenWindows?"On":"On"
			WinGet, pid, PID,% "ahk_id " hwnd ; we need the pid of process to open remote buffer
			DetectHiddenWindows % DetectHidden
			If !this.hProc:=DllCall("OpenProcess","uint",0x38,"int",0,"uint",pid,"Ptr") ;0x38 = PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE
				return DllCall("MessageBox","PTR",0,"Str","Unable to open process (" A_LastError ")","Str","OpenProcess Failed","UInt",0)
      this.size:=0 ; default size to 0
		} else if !this.hProc
			Return DllCall("MessageBox","PTR",0,"Str","No open process and no hWnd was given.","Str","OpenProcess Failed","UInt",0)
		If (size<>""&&size>this.size){ ; no size given = no buffer will be allocated
			this.size:=size ; new size
  		If this.RemoteBuf ; we already allocated buffer, free it now.
  			DllCall("VirtualFreeEx","PTR",this.hProc,"PTR",this.RemoteBuf,"PTR",0,"uint",MEM_RELEASE)
 			; Allocate new buffer
			If !this.RemoteBuf := DllCall("VirtualAllocEx","PTR",this.hProc,"PTR",0,"PTR",size,"uint",MEM_COMMIT,"uint",PAGE_READWRITE)
				return DllCall("MessageBox","PTR",0,"Str","Unable to allocate memory (" A_LastError ")","Str","OpenProcess Failed","UInt",0),this.hProc:=0
    }
		Return this.size
	}
	Read(size=0,offset=0){ ; Read remote buffer
		If !this.hProc
			return DllCall("MessageBox","PTR",0,"Str","Invalid remote buffer handle","Str","Handle is NULL","UInt",0)
		If (offset>this.size)
			DllCall("MessageBox","PTR",0,"Str","Offset (" offset ") is bigger then size (" this.size ")","Str","Offset bigger than size","UInt",0)
		this.SetCapacity("buffer",size?size:this.size) ; set internal capacity
		return DllCall("ReadProcessMemory","PTR",this.hProc,"PTR",this.RemoteBuf+offset,"PTR",this.LocalBuf:=this.GetAddress("buffer"),"uint",(size?size:this.size)+1,"uint",0)
	}
	Write(value,offset=0,CP=""){ ; Write Remote Buffer
		If !this.hProc
			return DllCall("MessageBox","PTR",0,"Str","Invalid remote buffer handle","Str","Handle is NULL","UInt",0)
		If (offset>this.size)
			return DllCall("MessageBox","PTR",0,"Str","Offset (" offset ") is larger then size (" this.size ")","Str","Offset bigger than size","UInt",0)
		If (value=""){ ; Write empty string
			return DllCall("WriteProcessMemory","PTR",this.hProc,"PTR",this.RemoteBuf+offset,"PTR",&value,"uint",4,"uint",0)
		} else {
			If (this.size<Strlen(value)*(CP="CP0"?1:2)) ; buffer to small, open new remote buffer
				this.Open(StrLen(value)*(CP="CP0"?1:2))
		}
		return DllCall("WriteProcessMemory","PTR",this.hProc,"PTR",this.RemoteBuf+offset,"PTR",&value,"uint",(StrLen(value)+1)*((CP="CP0"||this.Encoding="CP0")||CP=""?2:4),"uint",0)
	}
	NumPut(value=0,offset=0,Type="UInt"){
		If !this.hProc
			return DllCall("MessageBox","PTR",0,"Str","Invalid remote buffer handle","Str","Handle is NULL","UInt",0)
		If (offset>this.size)
			return DllCall("MessageBox","PTR",0,"Str","Offset (" offset ") is larger then size (" this.size ")","Str","Offset bigger than size","UInt",0)
		; Write value to remoteBuf
		this.SetCapacity("buffer",this.size),NumPut(value,this.LocalBuf:=this.GetAddress("buffer"),Type)
		return DllCall("WriteProcessMemory","PTR",this.hProc,"PTR",this.RemoteBuf+offset,"PTR",this.LocalBuf,"uint",A_PtrSize,"uint",0)
	}
	BinWrite(ByRef data,datasize,offset=0){
		If !this.hProc
			return DllCall("MessageBox","PTR",0,"Str","Invalid remote buffer handle","Str","Handle is NULL","UInt",0)
		If (offset>this.size)
			return DllCall("MessageBox","PTR",0,"Str","Offset (" offset ") is larger then size (" this.size ")","Str","Offset bigger than size","UInt",0)
		; Write value to remoteBuf
		this.SetCapacity("buffer",this.size),DllCall("RtlMoveMemory","PTR",this.LocalBuf:=this.GetAddress("buffer"),"PTR",&data,"PTR",datasize)
		return DllCall("WriteProcessMemory","PTR",this.hProc,"PTR",this.RemoteBuf+offset,"PTR",this.LocalBuf,"uint",datasize,"uint",0)
	}
}