' Retrieve the folder path from the command line argument
Dim folderPath
folderPath = WScript.Arguments(0)

' Create a Shell object
Set objShell = CreateObject("Shell.Application")

' Open Windows Explorer in the specified folder path
objShell.Explore folderPath