# setup-kiosk-browser.ps1
# OPTIONAL. Run ON THE HOST. Makes the 720x720 RDP session land straight on the target
# sites in a maximized/app-mode browser, so the Classic feels like a product, not a desktop.
#
# This creates a per-user startup shortcut that opens Edge (or Chrome) in --app mode at a
# launcher page. Adjust $Browser and $StartUrl to taste.

$Browser  = 'msedge'                       # or 'chrome'
$StartUrl = 'https://web.whatsapp.com/'    # change to your preferred default tile target

# app-mode = no tabs/address bar, maximized; closest thing to a framed product window.
$args = "--app=$StartUrl --start-maximized --new-window"

$startup = [Environment]::GetFolderPath('Startup')
$shortcut = Join-Path $startup 'BlackBerryBridge-Browser.lnk'

$exe = (Get-Command $Browser -ErrorAction SilentlyContinue).Source
if (-not $exe) {
    # Fall back to common install paths if not on PATH
    $candidates = @(
        "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    )
    $exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $exe) { throw "Could not find $Browser. Set `$Browser` or install it." }

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($shortcut)
$lnk.TargetPath = $exe
$lnk.Arguments  = $args
$lnk.Save()

Write-Host "Created startup shortcut: $shortcut" -ForegroundColor Green
Write-Host "It opens: $exe $args"
Write-Host "Remove it by deleting that .lnk to revert (fully reversible, per brief §12)."
