#!/usr/bin/env python3
"""A local stand-in for the dipro-board MCP server, for tests/test_stop.sh only.

It speaks MCP over HTTP (JSON answers) and has one tool, board_check, which answers what the DiPro Board server's
board_check answers for card #1 «New headline» held in Working by the calling session. Every tools/call is logged
as one JSON line, so the test can see what Claude Code sent.

    python3 stop_stub.py PORT LOG MODE     MODE = working (the session holds a card) or none (it holds nothing)
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT, LOG, MODE = int(sys.argv[1]), sys.argv[2], sys.argv[3]

KEEP_GOING = ('DiPro Board: card #1 «New headline» is still in Working and has no evidence, so it is not finished. '
              'Before you stop, post the evidence with board_update (card 1, to "review"): each Done-when line with what '
              'proves it. If it cannot be finished, post a note on the card saying what is done and what is missing, and '
              'ask the owner with board_ask.')
FOR_OWNER = ('DiPro stopped before card #1 «New headline» was finished: it is still in Working with no evidence. '
             'Type /dipro-board:work to continue it.')

TOOL = {'name': 'board_check', 'title': 'Check the card before stopping', 'description': 'Stop hook check (test stand-in).',
        'inputSchema': {'type': 'object', 'properties': {'session_id': {'type': 'string'}, 'stop_hook_active': {'type': 'string'}}},
        'annotations': {'readOnlyHint': True}}


def check(args):
    if MODE != 'working' or not args.get('session_id'):
        return {}
    if args.get('stop_hook_active') in (True, 'true'):
        return {'systemMessage': FOR_OWNER}
    return {'hookSpecificOutput': {'hookEventName': 'Stop', 'additionalContext': KEEP_GOING}}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def answer(self, status, body=None):
        data = b'' if body is None else json.dumps(body).encode()
        self.send_response(status)
        if body is not None:
            self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self.answer(405)

    def do_DELETE(self):
        self.answer(405)

    def do_POST(self):
        msg = json.loads(self.rfile.read(int(self.headers.get('Content-Length') or 0)) or b'{}')
        if 'id' not in msg:
            return self.answer(202)
        method, params = msg.get('method'), msg.get('params') or {}
        if method == 'initialize':
            result = {'protocolVersion': params.get('protocolVersion', '2025-06-18'), 'capabilities': {'tools': {'listChanged': False}},
                      'serverInfo': {'name': 'dipro-board', 'version': 'stub'}}
        elif method == 'tools/list':
            result = {'tools': [TOOL]}
        elif method == 'tools/call':
            args = params.get('arguments') or {}
            out = check(args) if params.get('name') == 'board_check' else None
            with open(LOG, 'a') as f:
                f.write(json.dumps({'tool': params.get('name'), 'arguments': args, 'answer': out}) + '\n')
            if out is None:
                return self.answer(200, {'jsonrpc': '2.0', 'id': msg['id'], 'error': {'code': -32602, 'message': 'Unknown tool'}})
            result = {'content': [{'type': 'text', 'text': json.dumps(out, ensure_ascii=False) if out else '{}'}], 'isError': False}
        else:
            result = {}
        self.answer(200, {'jsonrpc': '2.0', 'id': msg['id'], 'result': result})


HTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
