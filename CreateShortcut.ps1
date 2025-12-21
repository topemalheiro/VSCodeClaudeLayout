$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\VS Code Layout.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\Users\topem\Scripts\VSCodeClaudeLayout.ps1`""
$Shortcut.WorkingDirectory = "C:\Users\topem\Scripts"
$Shortcut.Description = "Snap VS Code to dual monitors (Ctrl+Alt+V hotkey)"
$Shortcut.Save()
Write-Host "Shortcut created on Desktop: VS Code Layout.lnk"
