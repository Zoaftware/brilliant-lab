#!/usr/bin/env bash
# Cases for hooks/guard_bd_writes.py: exit 2 = blocked, exit 0 = allowed.
cd "$(dirname "$0")/.." || exit 1
fails=0; total=0
check() {  # expected-exit json
  total=$((total + 1))
  printf '%s' "$2" | python3 hooks/guard_bd_writes.py 2>/dev/null
  got=$?
  if [ "$got" != "$1" ]; then fails=$((fails + 1)); echo "FAIL want $1 got $got: $2"; fi
}
check 2 '{"tool_name":"Bash","tool_input":{"command":"curl -X POST https://example.com/api/v2/user/update -H \"X-Api-Key: k\""}}'
check 2 '{"tool_name":"Bash","tool_input":{"command":"wget -qO- https://example.com/api/v2/user/get"}}'
check 2 '{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import requests; requests.put(u, headers={\\\"x-api-key\\\": k})\""}}'
check 2 '{"tool_name":"WebFetch","tool_input":{"url":"https://example.com/api/v2/user/get/1","prompt":"x"}}'
check 2 '{"tool_name":"WebFetch","tool_input":{"url":"https://example.com/%2Fapi%2Fv2%2Fuser/get/1","prompt":"x"}}'
check 2 '{"tool_name":"Bash","tool_input":{"command":"curl -X PUT https://example.com/api%252Fv2%252Fuser/update"}}'
check 2 '{"tool_name":"mcp__brilliant-directories__updateUser","tool_input":{}}'
check 2 '{"tool_name":"mcp__bd__deleteWebPage","tool_input":{}}'
check 2 '{"tool_name":"mcp__my-site__createWidget","tool_input":{}}'
check 2 '{"tool_name":"mcp__bd-mcp__createSomethingNew","tool_input":{}}'
check 2 '{"tool_name":"mcp__bd__refreshSiteCache","tool_input":{}}'
check 0 '{"tool_name":"mcp__brilliant-directories__listUsers","tool_input":{}}'
check 0 '{"tool_name":"mcp__plugin_dipro-board_dipro-board__site_apply","tool_input":{}}'
check 0 '{"tool_name":"mcp__plugin_dipro-board_dipro-board__dipro_instructions","tool_input":{"role":"dipro","phase":"start"}}'
check 0 '{"tool_name":"mcp__plugin_dipro-board_dipro-board__updateWidget","tool_input":{}}'
check 0 '{"tool_name":"mcp__github__create_issue","tool_input":{}}'
check 0 '{"tool_name":"mcp__notion__createPage","tool_input":{}}'
check 0 '{"tool_name":"Bash","tool_input":{"command":"grep -rn /api/v2/ docs"}}'
check 0 '{"tool_name":"Bash","tool_input":{"command":"curl -s https://zoaftware.com/mcp/dipro"}}'
check 0 '{"tool_name":"WebFetch","tool_input":{"url":"https://support.brilliantdirectories.com/x","prompt":"x"}}'
check 0 '{"tool_name":"Read","tool_input":{"file_path":"/tmp/a"}}'
check 0 'not json'
total=$((total + 1))  # the refusal names the server's real tools (underscores), so Claude can find them
msg=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"curl https://example.com/api/v2/user/get"}}' | python3 hooks/guard_bd_writes.py 2>&1)
case "$msg" in *"(site_read, site_apply, site_undo)"*) ;; *) fails=$((fails + 1)); echo "FAIL refusal text: $msg";; esac
echo "$((total - fails))/$total cases pass"
[ "$fails" = 0 ]
