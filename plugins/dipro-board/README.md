# DiPro Board

Ask for a change to your Brilliant Directories site, and DiPro makes it through your own Claude Code. A backup comes
first, and every change has an Undo.

## Install

```bash
claude plugin marketplace add zoaftware/brilliant-lab
claude plugin install dipro-board@brilliant-lab
```

Then open `/mcp`, pick **dipro-board** and sign in. The plugin never asks for your Claude password.

## What is inside

| Piece | What it does |
| --- | --- |
| `skills/dipro` | DiPro, the project manager: turns a request into a card and works it with DiDe and DiDev |
| `LICENSE` | All rights reserved: use only with a Brilliant Lab account |
| `skills/work` | `/dipro-board:work` takes the next card you started on your board |
| `agents/dide.md` | DiDe, the designer: mockups at 1440 and 390 px; never writes to your site |
| `agents/didev.md` | DiDev, the developer: audits the mockup, then builds through the server |
| `hooks/hooks.json` | Blocks direct calls to the BD API and the write tools of other BD MCP servers; before a session stops, asks the board whether its card still needs a plan or evidence |
| `.mcp.json` | The DiPro Board server, `https://zoaftware.com/mcp/dipro` (OAuth sign-in) |

## Where DiPro's instructions live

The skills and agents in this package are short. DiPro, DiDe and DiDev fetch their working instructions from the DiPro
Board server with the `dipro_instructions` tool, one phase at a time, while your plan is active. Each text names your
board on its first line, and each board has a daily number of reads.

What reaches your Claude Code stays on your computer, like any text your AI reads, so it cannot be made impossible to
copy. We keep it small (one phase at a time), mark it (the line that names your board) and protect it by license
(`LICENSE`: all rights reserved, use only with a Brilliant Lab account).

## How your site stays safe

- Your BD API key stays on our server. The plugin holds no key and no BD code.
- Every write goes through the server, inside a card you started, after a backup, with an Undo.
- The hook here is a second line only: the lock that counts is on the server.
- A session that holds a card in Planning or Working is not done until it posts the plan or the evidence: the board
  keeps it going once, then lets it stop and tells you to type `/dipro-board:work`. If Claude Code shows
  "Stop hook error", the board is not connected: open `/mcp` and sign in to **dipro-board**.
- The plugin never runs with permission checks off.

DiPro Board runs on Claude Code. It is made by Zoaftware and is not made or endorsed by Anthropic or Brilliant
Directories.

## Tests

```bash
bash tests/test_guard.sh    # the hook's cases: exit 2 = blocked, exit 0 = allowed
bash tests/test_stop.sh     # the Stop hook end to end, with a local stand-in of the server (three short haiku turns)
```
