# VS Code + Claude Code Dual-Monitor Layout Script
# Hotkey: Ctrl+Alt+V
# Snaps VS Code window to span both bottom monitors with Claude Code panel on right

param(
    [switch]$Once,      # Run once without hotkey listener (for testing)
    [switch]$Duplicate  # Duplicate window first, then snap
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WinAPI {
    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    // For message loop
    [DllImport("user32.dll")]
    public static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [DllImport("user32.dll")]
    public static extern bool TranslateMessage(ref MSG lpMsg);

    [DllImport("user32.dll")]
    public static extern IntPtr DispatchMessage(ref MSG lpMsg);

    // Mouse control
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, IntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    // Mouse event flags
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int x;
        public int y;
    }

    public const int WM_HOTKEY = 0x0312;
}
"@

# Load Windows Forms for SendKeys
Add-Type -AssemblyName System.Windows.Forms

# Window position settings for your monitors
# DISPLAY6 (left):  X=0,    Y=1083, WorkingArea height=1032
# DISPLAY5 (right): X=1920, Y=1002, WorkingArea height=1032
$TargetX = 0
$TargetY = 1083
$TargetWidth = 3840
$TargetHeight = 953

# Panel divider target position (X coordinate where monitors split)
$DividerTargetX = 1920

# Hotkey settings: Ctrl+Alt+V
$MOD_CONTROL = 0x0002
$MOD_ALT = 0x0001
$VK_V = 0x56
$HOTKEY_ID = 9999

function Find-VSCodeWindow {
    # First check if foreground window is VS Code
    $foreground = [WinAPI]::GetForegroundWindow()
    $titleLength = [WinAPI]::GetWindowTextLength($foreground)
    if ($titleLength -gt 0) {
        $sb = New-Object System.Text.StringBuilder($titleLength + 1)
        [WinAPI]::GetWindowText($foreground, $sb, $sb.Capacity) | Out-Null
        $title = $sb.ToString()
        if ($title -match "Visual Studio Code") {
            return $foreground
        }
    }

    # Otherwise find any VS Code window
    $vsCodeProcesses = Get-Process -Name "Code" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }

    foreach ($proc in $vsCodeProcesses) {
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $titleLength = [WinAPI]::GetWindowTextLength($proc.MainWindowHandle)
            if ($titleLength -gt 0) {
                $sb = New-Object System.Text.StringBuilder($titleLength + 1)
                [WinAPI]::GetWindowText($proc.MainWindowHandle, $sb, $sb.Capacity) | Out-Null
                $title = $sb.ToString()
                if ($title -match "Visual Studio Code" -or $title -match " - .+ - Visual Studio Code") {
                    return $proc.MainWindowHandle
                }
            }
        }
    }

    return $null
}


function Open-SecondaryPanel {
    param(
        [IntPtr]$hwnd,
        [switch]$SkipToggle  # Skip Ctrl+Alt+B if panel is already open
    )

    # Just ensure VS Code has focus - no click needed
    [WinAPI]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 100

    if (-not $SkipToggle) {
        Write-Host "  Opening Claude Code panel (Ctrl+Alt+B)..." -ForegroundColor Cyan
        [System.Windows.Forms.SendKeys]::SendWait("^%b")
        Start-Sleep -Milliseconds 300
        Write-Host "  Panel toggle sent" -ForegroundColor Green
    } else {
        Write-Host "  Skipping panel toggle (assuming already open)" -ForegroundColor Cyan
    }
}

function Move-PanelDivider {
    param(
        [int]$TargetX = 1920,
        [int]$WindowX = 0,
        [int]$WindowY = 1083,
        [int]$WindowWidth = 3840,
        [int]$WindowHeight = 953
    )

    Write-Host "  Dragging panel divider to X=$TargetX..." -ForegroundColor Cyan

    # Save original cursor position
    $originalPos = New-Object WinAPI+POINT
    [WinAPI]::GetCursorPos([ref]$originalPos) | Out-Null

    # Y position: Just below the title bar and tabs (~80px from top)
    $clickY = [int]($WindowY + 80)

    # Start position: Very close to right edge (100px from right)
    # This ensures we grab sash3 (auxiliary bar divider), not sash2 (editor group)
    $startX = $WindowX + $WindowWidth - 100

    Write-Host "    Drag: from X=$startX to X=$TargetX at Y=$clickY" -ForegroundColor Gray

    # Move cursor to start position
    [WinAPI]::SetCursorPos($startX, $clickY) | Out-Null
    Start-Sleep -Milliseconds 100

    # Mouse down
    [WinAPI]::mouse_event([WinAPI]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 50

    # Drag to target (incremental movement for smooth drag)
    $steps = 20
    $deltaX = ($TargetX - $startX) / $steps
    for ($i = 1; $i -le $steps; $i++) {
        $currentX = [int]($startX + ($deltaX * $i))
        [WinAPI]::SetCursorPos($currentX, $clickY) | Out-Null
        Start-Sleep -Milliseconds 10
    }

    # Mouse up
    [WinAPI]::mouse_event([WinAPI]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [IntPtr]::Zero)

    # Restore cursor
    [WinAPI]::SetCursorPos($originalPos.x, $originalPos.y) | Out-Null

    Write-Host "  Panel divider moved" -ForegroundColor Green
}

function Duplicate-VSCodeWindow {
    param([IntPtr]$hwnd)

    Write-Host "  Duplicating workspace in new window..." -ForegroundColor Cyan

    # Ensure VS Code has focus
    [WinAPI]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 100

    # Open command palette with Ctrl+Shift+P
    [System.Windows.Forms.SendKeys]::SendWait("^+p")
    Start-Sleep -Milliseconds 300

    # Type the command
    [System.Windows.Forms.SendKeys]::SendWait("Duplicate as Workspace in New Window")
    Start-Sleep -Milliseconds 300

    # Press Enter to execute
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

    Write-Host "  Waiting for new window to open..." -ForegroundColor Cyan
    Start-Sleep -Milliseconds 1500  # Wait for new window to spawn

    Write-Host "  Duplicate command sent" -ForegroundColor Green
}

function Invoke-LayoutSnap {
    param(
        [switch]$DuplicateFirst  # If set, duplicate the window before snapping
    )

    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Snapping VS Code window..."

    $hwnd = Find-VSCodeWindow

    if ($null -eq $hwnd -or $hwnd -eq [IntPtr]::Zero) {
        Write-Host "  No VS Code window found!" -ForegroundColor Yellow
        return $false
    }

    # Get window title for feedback
    $titleLength = [WinAPI]::GetWindowTextLength($hwnd)
    $sb = New-Object System.Text.StringBuilder($titleLength + 1)
    [WinAPI]::GetWindowText($hwnd, $sb, $sb.Capacity) | Out-Null
    Write-Host "  Found: $($sb.ToString())" -ForegroundColor Cyan

    # If DuplicateFirst flag is set, duplicate the window first
    if ($DuplicateFirst) {
        Duplicate-VSCodeWindow -hwnd $hwnd

        # Now find the NEW window (it should be the foreground window)
        Start-Sleep -Milliseconds 500
        $hwnd = [WinAPI]::GetForegroundWindow()

        $titleLength = [WinAPI]::GetWindowTextLength($hwnd)
        $sb = New-Object System.Text.StringBuilder($titleLength + 1)
        [WinAPI]::GetWindowText($hwnd, $sb, $sb.Capacity) | Out-Null
        Write-Host "  New window: $($sb.ToString())" -ForegroundColor Cyan
    }

    # Restore if minimized (SW_RESTORE = 9)
    [WinAPI]::ShowWindow($hwnd, 9) | Out-Null

    # Move and resize
    $result = [WinAPI]::MoveWindow($hwnd, $TargetX, $TargetY, $TargetWidth, $TargetHeight, $true)

    if ($result) {
        Write-Host "  Repositioned to: X=$TargetX, Y=$TargetY, ${TargetWidth}x${TargetHeight}" -ForegroundColor Green
        # Bring to front
        [WinAPI]::SetForegroundWindow($hwnd) | Out-Null

        # Small delay for window to render
        Start-Sleep -Milliseconds 100


        
        # Open the Claude Code panel
        Open-SecondaryPanel -hwnd $hwnd -SkipToggle

        Write-Host "  Layout complete - manually adjust panel divider once (VS Code remembers it)" -ForegroundColor Yellow

        return $true
    } else {
        Write-Host "  Failed to reposition window!" -ForegroundColor Red
        return $false
    }
}

# If -Once flag, just snap and exit
if ($Once) {
    if ($Duplicate) {
        Invoke-LayoutSnap -DuplicateFirst
    } else {
        Invoke-LayoutSnap
    }
    exit 0
}

# Main execution with hotkey listener
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  VS Code Claude Layout Script" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Hotkey: Ctrl+Alt+V" -ForegroundColor Yellow
Write-Host "  Target: Spans both bottom monitors"
Write-Host "          (${TargetWidth}x${TargetHeight} at $TargetX,$TargetY)"
Write-Host "  Divider: X=$DividerTargetX (center)"
Write-Host ""
Write-Host "  Press Ctrl+Alt+V to snap VS Code"
Write-Host "  Press Ctrl+C to exit"
Write-Host "============================================" -ForegroundColor Cyan

# Register hotkey (use thread ID 0 for global)
$registered = [WinAPI]::RegisterHotKey([IntPtr]::Zero, $HOTKEY_ID, ($MOD_CONTROL -bor $MOD_ALT), $VK_V)

if (-not $registered) {
    Write-Host ""
    Write-Host "ERROR: Failed to register Ctrl+Alt+V hotkey!" -ForegroundColor Red
    Write-Host "The hotkey may be in use by another application." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Hotkey registered. Listening..." -ForegroundColor Green

# Message loop
$msg = New-Object WinAPI+MSG

try {
    while ($true) {
        $result = [WinAPI]::GetMessage([ref]$msg, [IntPtr]::Zero, 0, 0)

        if ($result -eq 0 -or $result -eq -1) {
            break
        }

        if ($msg.message -eq [WinAPI]::WM_HOTKEY -and $msg.wParam -eq $HOTKEY_ID) {
            Invoke-LayoutSnap
        }

        [WinAPI]::TranslateMessage([ref]$msg) | Out-Null
        [WinAPI]::DispatchMessage([ref]$msg) | Out-Null
    }
} finally {
    [WinAPI]::UnregisterHotKey([IntPtr]::Zero, $HOTKEY_ID) | Out-Null
    Write-Host "`nHotkey unregistered. Goodbye!" -ForegroundColor Cyan
}
