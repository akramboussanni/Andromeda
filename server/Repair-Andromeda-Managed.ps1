& {
    $ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $root = Join-Path $env:LOCALAPPDATA 'AndromedaServer'
    $core = Join-Path $root 'core'
    $envPath = Join-Path $core '.env'
    $python = Join-Path $core 'venv\Scripts\python.exe'
    if (!(Test-Path -LiteralPath $envPath -PathType Leaf)) { throw "Existing server settings not found: $envPath" }
    if (!(Test-Path -LiteralPath $python -PathType Leaf)) { throw "Server Python environment not found: $python" }
    $text = [IO.File]::ReadAllText($envPath)
    $gameExe = & $python -c "import sys; from dotenv import dotenv_values; print(dotenv_values(sys.argv[1],encoding='utf-8-sig',interpolate=False).get('GAME_EXECUTABLE_PATH') or '')" $envPath
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read GAME_EXECUTABLE_PATH from server settings.' }
    $gameExe = ($gameExe -join '').Trim()
    if (!$gameExe) { $gameExe = Join-Path $root 'gameserver\game\enemy-on-board.exe' }
    if (![IO.Path]::IsPathRooted($gameExe)) { $gameExe = Join-Path $core $gameExe }
    if (!(Test-Path -LiteralPath $gameExe -PathType Leaf)) { throw "Installed game executable not found: $gameExe" }
    $game = Split-Path -Parent $gameExe
    $managed = Join-Path $game 'enemy-on-board_Data\Managed'
    if (!(Test-Path -LiteralPath $managed -PathType Container)) { throw "Installed game Managed folder not found: $managed" }
    $downloadPath = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name '{374DE290-123F-4565-9164-39C4925E467B}').'{374DE290-123F-4565-9164-39C4925E467B}'
    $downloads = [Environment]::ExpandEnvironmentVariables($downloadPath)
    $downloadedAssembly = Join-Path $downloads 'Assembly-CSharp.dll'
    if (!(Test-Path -LiteralPath $downloadedAssembly -PathType Leaf)) { throw "Required download not found: $downloadedAssembly" }
    $files = @{}
    Get-ChildItem -LiteralPath $managed -File -Filter '*.dll' | ForEach-Object { $files[$_.Name] = $_.FullName }
    $files.Remove('Assembly-CSharp-Publicized.dll')
    $files['Assembly-CSharp.dll'] = $downloadedAssembly
    foreach ($name in @('MelonLoader.dll','0Harmony.dll','Newtonsoft.Json.dll')) {
        $preferred = Join-Path $game "MelonLoader\net35\$name"
        if (Test-Path -LiteralPath $preferred -PathType Leaf) { $files[$name] = $preferred }
        elseif (!$files.ContainsKey($name)) {
            $loader = Join-Path $game 'MelonLoader'
            $found = @(Get-ChildItem -LiteralPath $loader -Recurse -File -Filter $name)
            if ($found.Count -ne 1) { throw "Expected exactly one $name in MelonLoader; found $($found.Count)." }
            $files[$name] = $found[0].FullName
        }
    }
    foreach ($name in @('Assembly-CSharp.dll','Assembly-CSharp-firstpass.dll','UnityEngine.dll','UnityEngine.CoreModule.dll','MelonLoader.dll','0Harmony.dll','Newtonsoft.Json.dll')) {
        if (!$files.ContainsKey($name)) { throw "Required dependency missing: $name" }
    }
    $hashes = @{}
    foreach ($name in $files.Keys) {
        $stream = [IO.File]::OpenRead($files[$name])
        try { if ($stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) { throw "Invalid DLL: $name" } } finally { $stream.Dispose() }
        $hashes[$name] = (Get-FileHash -LiteralPath $files[$name] -Algorithm SHA256).Hash
    }
    $zipDir = Join-Path $core 'data\managed'
    $zipPath = Join-Path $zipDir 'EnemyOnBoard_Managed.zip'
    $id = [Guid]::NewGuid().ToString('N')
    $tempZip = Join-Path $zipDir "managed.$id.tmp.zip"
    $tempEnv = "$envPath.$id.tmp"
    $backupEnv = "$envPath.$id.bak"
    $backupZip = "$zipPath.$id.bak"
    $changedZip = $false
    $hadZip = Test-Path -LiteralPath $zipPath -PathType Leaf
    if ($zipPath.Contains("'") -or $zipPath.Contains("`n") -or $zipPath.Contains("`r")) { throw 'Unsupported installation path quoting.' }
    $updated = [regex]::Replace($text, '(?m)^[ \t]*(?:export[ \t]+)?(?:MANAGED_ZIP_PATH|EOB_MANAGED_DEP_DIR)[ \t]*=.*(?:\r?\n|$)', '')
    $updated = $updated.TrimEnd([char[]]"`r`n") + "`r`nMANAGED_ZIP_PATH='$zipPath'`r`nEOB_MANAGED_DEP_DIR=''`r`n"
    New-Item -ItemType Directory -Path $zipDir -Force | Out-Null
    try {
        $archive = [IO.Compression.ZipFile]::Open($tempZip, [IO.Compression.ZipArchiveMode]::Create)
        try { foreach ($name in ($files.Keys | Sort-Object)) { [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $files[$name], $name, [IO.Compression.CompressionLevel]::Optimal) | Out-Null } } finally { $archive.Dispose() }
        $archive = [IO.Compression.ZipFile]::OpenRead($tempZip)
        try {
            if ($archive.Entries.Count -ne $files.Count) { throw 'ZIP entry count mismatch.' }
            foreach ($entry in $archive.Entries) {
                $stream = $entry.Open()
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-',''); if ($hash -ne $hashes[$entry.FullName]) { throw "ZIP verification failed: $($entry.FullName)" } } finally { $sha.Dispose(); $stream.Dispose() }
            }
        } finally { $archive.Dispose() }
        [IO.File]::WriteAllText($tempEnv, $updated, (New-Object Text.UTF8Encoding($false)))
        $verifiedPath = & $python -c "import sys; from dotenv import dotenv_values; print(dotenv_values(sys.argv[1],encoding='utf-8-sig',interpolate=False).get('MANAGED_ZIP_PATH') or '')" $tempEnv
        if ($LASTEXITCODE -ne 0 -or ($verifiedPath -join '') -ne $zipPath) { throw 'Updated .env path verification failed.' }
        if ([IO.File]::ReadAllText($envPath) -ne $text) { throw 'Server settings changed during repair; rerun the command.' }
        if ($hadZip) { [IO.File]::Replace($tempZip, $zipPath, $backupZip) } else { [IO.File]::Move($tempZip, $zipPath) }
        $changedZip = $true
        [IO.File]::Replace($tempEnv, $envPath, $backupEnv)
        $changedZip = $false
        Write-Host "Verified $($files.Count) DLLs. Created $zipPath and updated $envPath. Settings backup: $backupEnv. Restart the Andromeda Core server to load the updated settings."
    } catch {
        if ($changedZip) { if ($hadZip) { [IO.File]::Copy($backupZip, $zipPath, $true) } else { [IO.File]::Delete($zipPath) } }
        throw
    } finally {
        foreach ($temp in @($tempZip,$tempEnv)) { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
    }
}
