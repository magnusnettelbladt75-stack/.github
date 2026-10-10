# Få Claude Desktop att fungera

Skript som kör en **loop**: testar → provar nästa åtgärd → testar igen, tills Claude Desktop når sina servrar och alla MCP-kopplingar hittas.

| Test | Åtgärder som provas i tur och ordning |
|---|---|
| Appen installerad | 1. Töm DNS-cache |
| Når `claude.ai` och `api.anthropic.com` | 2. Återställ trasig `claude_desktop_config.json` (backup sparas) |
| Konfig-filen är giltig JSON | 3. Starta om appen |
| MCP-serverns kommando (`npx`, `uvx`, `node` …) finns | 4. Rensa cache |
| | 5. Kontrollera VPN/proxy/brandvägg |
| | 6. Ominstallera från claude.ai/download |

När alla åtgärder är provade fortsätter loopen att testa var 60:e sekund och visar de senaste loggraderna.

## Mac
```bash
bash fix-claude-desktop-mac.sh
```

## Windows (PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File .\fix-claude-desktop-windows.ps1
```

## Vanligaste felet med MCP-kopplingar
Claude Desktop ser inte terminalens `PATH`. Skriv full sökväg i konfigen, t.ex. `"command": "/opt/homebrew/bin/npx"` (Mac) eller `"command": "C:\\Program Files\\nodejs\\npx.cmd"` (Windows), och starta om appen.
