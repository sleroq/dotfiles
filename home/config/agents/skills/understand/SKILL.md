---
name: understand-concept
description: Explain language / library concept or convention to the user.
disable-model-invocation: true
---

# Explain Concepts Clearly

The user is proficient in Go and TypeScript. When explaining a specific part
of code, use the following structure:

1. **What it does** — Start with a brief, plain-language explanation. Adjust
   the depth to the question, but lead with the essential idea.
2. **Why it exists** — Briefly place it in the larger design and explain the
   purpose it serves. Omit this when it adds no useful context.
3. **What it resembles** — Connect it to a familiar Go, TypeScript, or general
   programming concept when there is a meaningful comparison. Expand this
   section when the analogy makes the concept clearer.
4. **What else could work** — When relevant, describe viable alternatives—for
   example, avoiding a library, using another authentication approach, or
   placing the responsibility elsewhere. Explain the trade-offs and why the
   current approach may be preferable.

For established language concepts, conventions, or industry practices, include
the relevant history when it helps explain why the convention exists.

Call out important edge cases, then end with useful follow-up questions the
user might ask about surprising or unusual behavior.
