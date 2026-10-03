$ErrorActionPreference = "Stop"
$release = "https://github.com/akramboussanni/Andromeda/releases/latest/download/Andromeda.Server.Windows.zip"
$root = Join-Path $env:LOCALAPPDATA "AndromedaServer"
$zip = Join-Path $env:TEMP "Andromeda.Server.Windows.zip"

Write-Host "Downloading the Andromeda Windows server bundle..."
Invoke-WebRequest -UseBasicParsing -Uri $release -OutFile $zip
if (Test-Path $root) {
    $backup = "$root.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Move-Item $root $backup
    Write-Host "Previous installation backed up to $backup"
}
New-Item -ItemType Directory -Force -Path $root | Out-Null
Expand-Archive -Path $zip -DestinationPath $root -Force
Remove-Item $zip -Force

$setup = Join-Path $root "core\Setup-Andromeda-Server.bat"
if (-not (Test-Path $setup)) { throw "The downloaded server bundle is missing $setup" }
Start-Process -FilePath $setup -WorkingDirectory (Split-Path $setup) -Wait
