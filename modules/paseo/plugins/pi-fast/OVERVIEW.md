# Pi Fast

Adds a Fast menu beside Tasks and Subagents in each Pi agent's composer, with explicit Enable and Disable actions. Enabling Fast can increase OpenAI subscription usage.

Requires Paseo 0.13 and the local Pi extension that registers `/fast`. The menu checks that the command is loaded before sending `/fast on` or `/fast off`. It is disabled while the agent is running or initializing, so changing Fast mode does not interrupt work.

Fast remains off until enabled and resets to off when Pi starts a new session. The menu does not claim to display the current state. The Pi extension applies Fast only to OpenAI subscription requests; API-key requests and other providers remain unchanged.
