$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\VS Code Layout.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\Users\topem\Scripts\VSCodeClaudeLayout\VSCodeClaudeLayout.ps1`""
$Shortcut.WorkingDirectory = "C:\Users\topem\Scripts\VSCodeClaudeLayout"
$Shortcut.Description = "VS Code Layout (Ctrl+Alt+V dual, Ctrl+Alt+N single)"
$Shortcut.Save()
Write-Host "Shortcut created on Desktop: VS Code Layout.lnk"
