# Felsökningsloop för Claude Desktop på Windows.
# Testar anslutning, konfiguration och MCP-kopplingar. Om något fallerar
# provas nästa åtgärd, sedan testas allt igen – tills allt fungerar.
# Kör i PowerShell:  powershell -ExecutionPolicy Bypass -File .\fix-claude-desktop-windows.ps1

$CfgDir = Join-Path $env:APPDATA 'Claude'
$Cfg    = Join-Path $CfgDir 'claude_desktop_config.json'
$Logs   = Join-Path $CfgDir 'logs'
$Exe    = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
$RetrySeconds = 60

function Ok($m)   { Write-Host "  [OK]  $m" -ForegroundColor Green }
function Fail($m) { Write-Host "  [FEL] $m" -ForegroundColor Red }
function Info($m) { Write-Host "`n$m" -ForegroundColor Cyan }

function Test-Reachable($url) {
    # Vilket HTTP-svar som helst (även 403/404) betyder att servern nås.
    try { Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 10 | Out-Null; return $true }
    catch { return [bool]$_.Exception.Response }
}

function Get-Config { try { return Get-Content $Cfg -Raw | ConvertFrom-Json } catch { return $null } }

function Run-Tests {
    $problems = 0
    Info 'Test'
    if ((Test-Path $Exe) -or (Get-AppxPackage -Name '*Claude*' -ErrorAction SilentlyContinue)) { Ok 'Claude Desktop är installerad' }
    else { Fail 'Claude Desktop hittas inte'; $problems++ }
    foreach ($url in 'https://claude.ai', 'https://api.anthropic.com') {
        if (Test-Reachable $url) { Ok "Når $url" } else { Fail "Når inte $url"; $problems++ }
    }
    if (Test-Path $Cfg) {
        $c = Get-Config
        if ($null -eq $c) { Fail 'claude_desktop_config.json är INTE giltig JSON'; $problems++ }
        else {
            Ok 'claude_desktop_config.json är giltig JSON'
            if ($c.mcpServers) {
                foreach ($p in $c.mcpServers.PSObject.Properties) {
                    $cmd = $p.Value.command
                    if ((Test-Path $cmd -ErrorAction SilentlyContinue) -or (Get-Command $cmd -ErrorAction SilentlyContinue)) {
                        Ok "MCP '$($p.Name)': '$cmd' finns"
                    } else { Fail "MCP '$($p.Name)': kommandot '$cmd' hittas inte (installera t.ex. Node.js / ange full sökväg)"; $problems++ }
                }
            }
        }
    } else { Ok 'Ingen MCP-konfig (standardläge)' }
    return $problems
}

function Stop-Claude { Get-Process -Name 'claude' -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 3 }
function Start-Claude { if (Test-Path $Exe) { Start-Process $Exe } else { Start-Process 'shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude' -ErrorAction SilentlyContinue }; Start-Sleep 5 }

function Fix-Dns     { Write-Host 'Tömmer DNS-cache…'; ipconfig /flushdns | Out-Null }
function Fix-Config  {
    if ((Test-Path $Cfg) -and $null -eq (Get-Config)) {
        Copy-Item $Cfg "$Cfg.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Set-Content $Cfg '{}' -Encoding UTF8
        Write-Host 'Trasig konfig säkerhetskopierad och ersatt med {}.'
    } else { Write-Host 'Konfigen behöver inte återställas.' }
}
function Fix-Restart { Write-Host 'Startar om Claude…'; Stop-Claude; Start-Claude }
function Fix-Cache   {
    Write-Host 'Rensar Claudes cache…'; Stop-Claude
    'Cache', 'Code Cache', 'GPUCache' | ForEach-Object { Remove-Item (Join-Path $CfgDir $_) -Recurse -Force -ErrorAction SilentlyContinue }
    Start-Claude
}
function Fix-Proxy   {
    Write-Host 'Proxy-inställningar (VPN/proxy/brandvägg kan blockera):'; netsh winhttp show proxy
    Read-Host 'Stäng av VPN/proxy tillfälligt och tillåt Claude i brandväggen, tryck sedan Enter'
}
function Fix-Reinstall {
    Write-Host 'Installera om: ladda ner senaste versionen från https://claude.ai/download'
    Start-Process 'https://claude.ai/download'; Read-Host 'Tryck Enter när det är klart'
}

$Fixes = 'Fix-Dns', 'Fix-Config', 'Fix-Restart', 'Fix-Cache', 'Fix-Proxy', 'Fix-Reinstall'
$i = 0
while ($true) {
    if ((Run-Tests) -eq 0) { Info 'Allt fungerar! Öppna Claude Desktop och logga in.'; break }
    if ($i -lt $Fixes.Count) {
        Info "Åtgärd $($i + 1)/$($Fixes.Count): $($Fixes[$i])"
        & $Fixes[$i]; $i++
    } else {
        Info 'Alla åtgärder provade. Senaste loggrader:'
        Get-ChildItem $Logs -Filter *.log -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "--- $($_.Name)"; Get-Content $_.FullName -Tail 15 }
        Write-Host "Testar igen om $RetrySeconds s (Ctrl+C för att avbryta)…"; Start-Sleep $RetrySeconds
    }
}
