---
name: work
description: Take the next card from the owner's DiPro Board and work it with DiPro until it waits for the owner. Use when the owner types /dipro-board:work or says "work the next card", "take the next card", "check my board" or "what is next on my board".
---

# Work the next card

Your session id is `${CLAUDE_SESSION_ID}`. Pass it as `session_id` on every `dipro-board` call, including wherever
your instructions ask for the session id.

1. Call `dipro_instructions` on the `dipro-board` MCP server with `role: "work"` and `phase: "steps"`, and follow it.
2. If the answer has `error` set to `subscription_ended` or `daily_limit`, give the owner its `message` and stop.
3. If the `dipro-board` tools are not there, or the server says this sign-in is not valid, ask the owner to type
   `/mcp`, choose **dipro-board** and sign in, then run `/dipro-board:work` again. Do nothing else until then, and use
   no other tool or server instead.
