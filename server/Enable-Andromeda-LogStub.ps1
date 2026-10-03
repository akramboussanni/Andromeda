& {
    $ErrorActionPreference = 'Stop'
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (!$admin) { throw 'Run this command in PowerShell opened as Administrator (using the same Windows account as the server installation).' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $core = Join-Path $env:LOCALAPPDATA 'AndromedaServer\core'
    $envPath = Join-Path $core '.env'
    $target = Join-Path $core 'log_server.py'
    $python = Join-Path $core 'venv\Scripts\python.exe'
    foreach ($path in @($envPath,$target,$python)) { if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Existing server file not found: $path" } }
    $text = [IO.File]::ReadAllText($envPath)
    $updated = [regex]::Replace($text, '(?m)^[ \t]*(?:export[ \t]+)?(?:ENABLE_LOG_SERVER|LOG_SERVER_MODE|LOG_SERVER_PORT)[ \t]*=.*(?:\r?\n|$)', '')
    $updated = $updated.TrimEnd([char[]]"`r`n") + "`r`nENABLE_LOG_SERVER=true`r`nLOG_SERVER_MODE=stub`r`nLOG_SERVER_PORT=9090`r`n"
    $id = [Guid]::NewGuid().ToString('N')
    $temp = Join-Path $core "log_server.$id.tmp.py"
    $tempEnv = "$envPath.$id.tmp"
    $backup = "$target.$id.bak"
    $backupEnv = "$envPath.$id.bak"
    $changed = $false
    $ruleName = 'Andromeda-LogStub-TCP-9090'
    $createdRule = $false
    try {
        Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/akramboussanni/Andromeda.Core/66d970371a091b045340240a4ff3287f3235f4a8/log_server.py' -OutFile $temp
        if ((Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash -ne '41666320c9c229eea3bd77781308e4e5ad51988c15efea025c93ba9636f55eb9') { throw 'Downloaded log server hash mismatch.' }
        & $python -c "import ast,sys; ast.parse(open(sys.argv[1],encoding='utf-8-sig').read())" $temp
        if ($LASTEXITCODE -ne 0) { throw 'Downloaded listener failed Python syntax validation.' }
        [IO.File]::WriteAllText($tempEnv, $updated, (New-Object Text.UTF8Encoding($false)))
        if ([IO.File]::ReadAllText($envPath) -ne $text) { throw 'Server settings changed during update; rerun the command.' }
        $rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
        if ($rule) {
            $port = $rule | Get-NetFirewallPortFilter
            if ($rule.Enabled -ne 'True' -or $rule.Direction -ne 'Inbound' -or $rule.Action -ne 'Allow' -or $port.Protocol -ne 'TCP' -or $port.LocalPort -ne '9090') { throw 'Existing log stub firewall rule conflicts with expected TCP 9090 settings.' }
        } else {
            New-NetFirewallRule -Name $ruleName -DisplayName 'Andromeda TCP log stub (9090)' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9090 -Profile Any | Out-Null
            $createdRule = $true
        }
        [IO.File]::Replace($temp, $target, $backup)
        $changed = $true
        [IO.File]::Replace($tempEnv, $envPath, $backupEnv)
        $changed = $false
        $createdRule = $false
        Write-Host "Updated $target; enabled TCP log stub on port 9090. Backups: $backup and $backupEnv. Stop and restart Andromeda Core to activate it."
    } catch {
        if ($changed) { [IO.File]::Copy($backup, $target, $true) }
        if ($createdRule) { Remove-NetFirewallRule -Name $ruleName }
        throw
    } finally {
        foreach ($path in @($temp,$tempEnv)) { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
    }
}
