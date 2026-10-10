#!/usr/bin/env bash
# Felsökningsloop för Claude Desktop på macOS.
# Testar anslutning, konfiguration och MCP-kopplingar. Om något fallerar
# provas nästa åtgärd, sedan testas allt igen – tills allt fungerar.
# Kör:  bash fix-claude-desktop-mac.sh

CFG_DIR="$HOME/Library/Application Support/Claude"
CFG="$CFG_DIR/claude_desktop_config.json"
LOGS="$HOME/Library/Logs/Claude"
APP="/Applications/Claude.app"
RETRY_SECONDS=60

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$*"; }
info() { printf '\n\033[1m%s\033[0m\n' "$*"; }

reachable() { # Vilket HTTP-svar som helst (även 403/404) betyder att servern nås.
  local code; code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$1")
  [ -n "$code" ] && [ "$code" != "000" ]
}

json_ok() {
  osascript -l JavaScript -e "JSON.parse(\$.NSString.stringWithContentsOfFileEncodingError('$1', \$.NSUTF8StringEncoding, null).js)" >/dev/null 2>&1
}

mcp_commands() {
  osascript -l JavaScript -e "
    var c = JSON.parse(\$.NSString.stringWithContentsOfFileEncodingError('$CFG', \$.NSUTF8StringEncoding, null).js);
    var s = c.mcpServers || {}; Object.keys(s).map(function(k){ return k + '\t' + (s[k].command || ''); }).join('\n');" 2>/dev/null
}

run_tests() {
  local problems=0
  info "Test"
  [ -d "$APP" ] && ok "Claude.app är installerad" || { fail "Claude.app saknas i /Applications"; problems=$((problems+1)); }
  for url in https://claude.ai https://api.anthropic.com; do
    reachable "$url" && ok "Når $url" || { fail "Når inte $url"; problems=$((problems+1)); }
  done
  if [ -f "$CFG" ]; then
    if json_ok "$CFG"; then
      ok "claude_desktop_config.json är giltig JSON"
      while IFS=$'\t' read -r name cmd; do
        [ -z "$name" ] && continue
        if [[ "$cmd" == /* ]] && [ -x "$cmd" ]; then ok "MCP '$name': $cmd finns"
        elif [[ "$cmd" != /* ]] && command -v "$cmd" >/dev/null; then
          ok "MCP '$name': '$cmd' finns i terminalen ($(command -v "$cmd"))"
          echo "      Tips: appen ser inte terminalens PATH – använd hela sökvägen \"$(command -v "$cmd")\" i konfigen."
        else fail "MCP '$name': kommandot '$cmd' hittas inte"; problems=$((problems+1)); fi
      done <<< "$(mcp_commands)"
    else
      fail "claude_desktop_config.json är INTE giltig JSON"; problems=$((problems+1))
    fi
  else
    ok "Ingen MCP-konfig (standardläge)"
  fi
  return $problems
}

fix_dns()      { echo "Tömmer DNS-cache (kräver lösenord)…"; sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; }
fix_config()   {
  [ -f "$CFG" ] && ! json_ok "$CFG" || { echo "Konfigen behöver inte återställas."; return; }
  cp "$CFG" "$CFG.backup-$(date +%Y%m%d-%H%M%S)"
  echo '{}' > "$CFG"; echo "Trasig konfig säkerhetskopierad och ersatt med {}."
}
fix_restart()  { echo "Startar om Claude…"; osascript -e 'quit app "Claude"' 2>/dev/null; sleep 3; pkill -x Claude 2>/dev/null; open -a Claude 2>/dev/null; sleep 5; }
fix_cache()    {
  echo "Rensar Claudes cache…"; osascript -e 'quit app "Claude"' 2>/dev/null; sleep 3
  rm -rf "$CFG_DIR/Cache" "$CFG_DIR/Code Cache" "$CFG_DIR/GPUCache" "$HOME/Library/Caches/com.anthropic.claudefordesktop"*
  open -a Claude 2>/dev/null
}
fix_proxy()    { echo "Proxy-inställningar (VPN/proxy kan blockera):"; scutil --proxy | grep -E 'Enable|Proxy' ; echo "Stäng av VPN/proxy tillfälligt och tryck Enter."; read -r; }
fix_reinstall(){ echo "Installera om: ladda ner senaste versionen från https://claude.ai/download och dra till Program."; open "https://claude.ai/download"; echo "Tryck Enter när det är klart."; read -r; }

FIXES=(fix_dns fix_config fix_restart fix_cache fix_proxy fix_reinstall)
i=0
while true; do
  if run_tests; then
    info "✅ Allt fungerar! Öppna Claude Desktop och logga in."
    exit 0
  fi
  if [ $i -lt ${#FIXES[@]} ]; then
    info "Åtgärd $((i+1))/${#FIXES[@]}: ${FIXES[$i]}"
    ${FIXES[$i]}; i=$((i+1))
  else
    info "Alla åtgärder provade. Senaste loggrader:"
    tail -n 15 "$LOGS"/*.log 2>/dev/null
    echo "Testar igen om $RETRY_SECONDS s (Ctrl+C för att avbryta)…"; sleep $RETRY_SECONDS
  fi
done
