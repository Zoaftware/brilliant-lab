# brilliant-lab

Zoaftware's Claude Code plugin marketplace for Brilliant Directories site owners.

| Plugin | What it does |
| --- | --- |
| [`dipro-board`](plugins/dipro-board/README.md) | Ask for a change to your BD site; DiPro makes it with a backup first and an Undo |

```bash
claude plugin marketplace add zoaftware/brilliant-lab
claude plugin install dipro-board@brilliant-lab
```

## Checks

```bash
claude plugin validate --strict .                       # the marketplace
claude plugin validate --strict ./plugins/dipro-board   # the plugin
bash plugins/dipro-board/tests/test_guard.sh            # the hook's cases
python3 tests/test_no_soul.py                           # no line of DiPro's instructions in the repo
```
