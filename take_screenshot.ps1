param(
    [string]$WindowTitle = "MTA: San Andreas",
    [string]$OutputPath = "screenshot.png"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Add Windows API definitions
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    public class User32
    {
        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);
    }
"@

# Find window by title
$window = Get-Process | Where-Object {$_.MainWindowTitle -like "*$WindowTitle*"} | Select-Object -First 1

if ($window -and $window.MainWindowHandle -ne [IntPtr]::Zero) {
    $rect = New-Object RECT
    [User32]::GetWindowRect($window.MainWindowHandle, [ref]$rect)

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    if ($width -gt 0 -and $height -gt 0) {
        $bitmap = New-Object System.Drawing.Bitmap($width, $height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)

        $bitmap.Save($OutputPath)
        $graphics.Dispose()
        $bitmap.Dispose()

        Write-Output "Screenshot saved: $OutputPath ($width x $height)"
    } else {
        Write-Error "Invalid window dimensions"
    }
} else {
    Write-Error "Window with title '*$WindowTitle*' not found"
}