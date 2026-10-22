#!/usr/bin/env python3
"""PreToolUse guard: DiPro reaches a BD site only through the dipro-board MCP server.

Blocks (exit 2, reason on stderr):
  - Bash commands that call the BD API directly (an HTTP client plus /api/v2/ or an X-Api-Key header);
  - WebFetch of a BD API route (/api/v2/);
  - write tools of any other MCP server that exposes the BD API (the official BD MCP and copies of it).

This is the second line only: the owner controls their computer, so the lock that counts is on our server.
Input that is not JSON is let through on purpose: Claude Code always sends JSON, and a guard that failed closed would
block every tool if that ever changed.
"""
import json
import re
import sys
from urllib.parse import unquote

# Write tools of the official BD MCP (brilliant-directories-mcp 6.58.612, mcp/openapi/bd-api.json:
# POST/PUT/DELETE operations named create*, update*, delete*, login*, refresh*, match*).
BD_WRITE_TOOLS = set('''
    createCategoryTree createClick createDataType createEmailTemplate createForm createFormField createLead
    createLeadMatch createMemberSubCategoryLink createMenu createMenuItem createMultiImagePost
    createMultiImagePostPhoto createRedirect createReview createSingleImagePost createSmartList
    createSubCategory createTag createTagGroup createTagRelationship createTopCategory createUnsubscribe
    createUser createUserMeta createUserPhoto createWebPage createWidget deleteClick deleteDataType
    deleteEmailTemplate deleteForm deleteFormField deleteLead deleteLeadMatch deleteMemberSubCategoryLink
    deleteMenu deleteMenuItem deleteMultiImagePost deleteMultiImagePostPhoto deletePostType deleteRedirect
    deleteReview deleteSingleImagePost deleteSmartList deleteSubCategory deleteTag deleteTagGroup
    deleteTagRelationship deleteTopCategory deleteUnsubscribe deleteUser deleteUserMeta deleteUserPhoto
    deleteWebPage deleteWidget loginUser matchLead refreshSiteCache updateCity updateClick updateCountry
    updateDataType updateEmailTemplate updateForm updateFormField updateLead updateLeadMatch
    updateMemberSubCategoryLink updateMenu updateMenuItem updateMultiImagePost updateMultiImagePostPhoto
    updatePostType updateRedirect updateReview updateSingleImagePost updateSmartList updateState
    updateSubCategory updateTag updateTagGroup updateTagRelationship updateTopCategory updateUnsubscribe
    updateUser updateUserMeta updateUserPhoto updateWebPage updateWidget
'''.split())

HTTP_CLIENT = re.compile(r'\b(curl|wget|http|https|xh|Invoke-WebRequest|Invoke-RestMethod|iwr|irm|fetch|requests|urllib|httpx|axios)\b', re.I)
BD_API = re.compile(r'/api/v2/|x-api-key', re.I)
BD_SERVER = re.compile(r'brilliant|(^|[-_])bd([-_]|$)', re.I)
BD_WRITE_SHAPE = re.compile(r'^(create|update|delete)[A-Z]')
OWN_SERVER = re.compile(r'dipro[-_]board', re.I)


def decoded(text):
    """Undo percent-encoding (up to 3 layers), so /%2Fapi%2Fv2%2F is seen as /api/v2/."""
    for _ in range(3):
        plain = unquote(text)
        if plain == text:
            break
        text = plain
    return text


def reason(data):
    tool = data.get('tool_name') or ''
    inp = data.get('tool_input') or {}
    if tool == 'Bash':
        cmd = decoded(str(inp.get('command') or ''))
        if BD_API.search(cmd) and HTTP_CLIENT.search(cmd):
            return 'calls the BD API directly'
    elif tool == 'WebFetch':
        if BD_API.search(decoded(str(inp.get('url') or ''))):
            return 'fetches a BD API route directly'
    elif tool.startswith('mcp__'):
        parts = tool.split('__', 2)
        server, name = (parts[1], parts[2]) if len(parts) == 3 else ('', '')
        if OWN_SERVER.search(server):
            return None
        if name in BD_WRITE_TOOLS or (BD_SERVER.search(server) and BD_WRITE_SHAPE.match(name)):
            return 'writes to a BD site through another MCP server (%s)' % name
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    why = reason(data)
    if not why:
        return 0
    sys.stderr.write(
        'DiPro Board blocked this: it %s. Changes to a Brilliant Directories site go only through the '
        'dipro-board MCP server (site_read, site_apply, site_undo), inside a started card, with a backup '
        'and an Undo.\n' % why)
    return 2


if __name__ == '__main__':
    sys.exit(main())
