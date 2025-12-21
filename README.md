# VS Code Claude Layout

PowerShell script to snap VS Code window across dual monitors with Claude Code panel on the right.

## Features

- **Hotkey**: `Ctrl+Alt+V` snaps current VS Code window
- **Window positioning**: Spans two bottom monitors (3840x953 at 0,1083)
- **Panel divider**: Drags Claude Code panel divider to center (X=1920)
- **Duplicate option**: Can duplicate workspace before snapping

## Usage

### One-time snap (testing)
```powershell
powershell -ExecutionPolicy Bypass -File VSCodeClaudeLayout.ps1 -Once
```

### Duplicate window then snap
```powershell
powershell -ExecutionPolicy Bypass -File VSCodeClaudeLayout.ps1 -Once -Duplicate
```

### Run as hotkey listener (background)
```powershell
powershell -ExecutionPolicy Bypass -File VSCodeClaudeLayout.ps1
```

## Installation

1. Run `CreateShortcut.ps1` to create a desktop shortcut
2. Optionally add the shortcut to `shell:startup` for auto-run on login

## Configuration

Edit these values in `VSCodeClaudeLayout.ps1` to match your monitor setup:

```powershell
$TargetX = 0          # Window X position
$TargetY = 1083       # Window Y position
$TargetWidth = 3840   # Window width (spans 2 monitors)
$TargetHeight = 953   # Window height
$DividerTargetX = 1920  # Panel divider position (center)
```

## Files

- `VSCodeClaudeLayout.ps1` - Main script
- `CreateShortcut.ps1` - Creates desktop shortcut
