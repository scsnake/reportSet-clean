function GetDS()
    {        
        try 
        {
            var empno=document.getElementById('hiddenEmpno').value;
            var cardOwnerEmpno=document.getElementById('hiddenCardOwnerEmpno').value;
            var pinCode=document.getElementById('hiddenPinCode').value;
            var hl7reg=document.getElementById('hiddenhl7reg').value;
            var readerType=document.getElementById('hiddenReaderType').value;
            var strEmrindexidse = document.getElementById('hiddenStrEmrindexidse').value;
            var lishost = document.getElementById('hiddenlisthost').value;
            
            var showMessage ="";
            if (readerType.length ==0)
            {
                if (pinCode.length ==0)
                {
                    if (strEmrindexidse.length==0)
                    {
                        showMessage = document.getElementById("HCACardAPI").MakeSignature(empno,cardOwnerEmpno,'','','',hl7reg,'H','N',lishost);
                    }
                    else
                    {
                        showMessage = document.getElementById('HCACardAPI').MakeSignatureReplace(empno, cardOwnerEmpno, '', '', '', hl7reg, 'H', 'N', strEmrindexidse, lishost);
                    }
                }
                else
                {
                    if (strEmrindexidse.length==0)
                    {
                        showMessage = document.getElementById('HCACardAPI').MakeSignature(empno, cardOwnerEmpno, pinCode, '', '', hl7reg, 'P', 'N', lishost);
                    }
                    else
                    {
                        showMessage = document.getElementById('HCACardAPI').MakeSignatureReplace(empno, cardOwnerEmpno, pinCode, '', '', hl7reg, 'P', 'N', strEmrindexidse, lishost);
                    }
                }
            }
            else if (readerType=="P")
            {
                if (strEmrindexidse.length==0)
                {
                    showMessage = document.getElementById('HCACardAPI').MakeSignature(empno, cardOwnerEmpno, pinCode, '', '', hl7reg, 'P', 'N', lishost);
                }
                else
                {
                    showMessage = document.getElementById('HCACardAPI').MakeSignatureReplace(empno, cardOwnerEmpno, pinCode, '', '', hl7reg, 'P', 'N', strEmrindexidse, lishost);
                }
            }
            else
            {
                if (strEmrindexidse.length==0)
                {
                    showMessage = document.getElementById('HCACardAPI').MakeSignature(empno, cardOwnerEmpno, pinCode, '', '', hl7reg, 'H', 'N', lishost);
                }
                else
                {
                    showMessage = document.getElementById('HCACardAPI').MakeSignatureReplace(empno, cardOwnerEmpno, pinCode, '', '', hl7reg, 'H', 'N', strEmrindexidse, lishost);
                }
            }
            
            
            alert(showMessage);
            window.close();
            
        }catch(err) {alert(err.message);}        
        
    }
		
setTimeout(GetDS, 1000);