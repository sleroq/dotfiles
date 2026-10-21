---
name: commit-pr
description: "Write, review, or improve Git commit messages and GitHub PR descriptions. Use when the user asks for a commit message or a PR description."
---

# Commit and PR Descriptions

Write so a reader learns **why** the change happened, not what changed.
The diff shows *what*; the description supplies only the *why*.

Sources: cbea.ms/git-commit and tbaggery.com/2008/04/19/a-note-about-git-commit-messages.

## Match the repo first

Before writing, read local history and follow its conventions:

```bash
git log -20 --format='%s%n%b---'
```

Match the subject dialect (plain imperative vs `type:` prefixes), trailer and
ticket-reference style, wrapping habits, and language. Fall back to the
defaults below only when history gives no signal.

## Commit template

```text
Capitalize the subject, ~50 chars, imperative, no final period

Optional body: how it worked before, what was wrong with that, and why
another direction would be worse. Wrap every line at 72 characters.
Never state what changed and how — the diff shows both.

- Bullets are okay: hyphen, single space
- Blank lines between multi-line bullets

Resolves: #123
See also: #456, #789
```

- Imperative test: the subject must complete "If applied, this commit will
  ___." Good: `Fix race in cache eviction`. Wrong: `Fixed race...`,
  `Fixing race...`.
- The body explains why, not what. Allowed: facts the diff cannot show
  (failure cause, user / cost impact, rejected alternative, tradeoff).
  Forbidden: any sentence reconstructible from the diff — imperatives like
  `Treat / Use / Add / Keep / Split / Pin / Switch`, `We now…`, or a tool /
  model / flag name stated as an instruction. State facts: "Psycopg 3 exposes
  the first result…", not "Use one result-producing statement…".
- Subtraction test (mandatory before output): cover the diff, read the body
  alone. If you can guess what code does, delete that sentence. If nothing
  remains, ship subject-only. Mention the fix only as `because + outside-diff
  fact`, never as an action.
- Never end the body with the change restated as an action. The last sentence
  must state the cost of doing nothing, the reason the alternative loses, or
  the tradeoff.
- A single title can be the whole message. When the subject and the diff make
  the why obvious (`Fix typo in installation guide`), skip the body.
- If the subject won't fit in ~50 characters, the commit probably does too
  much — prefer splitting into atomic commits.
- Never append generated attribution footers or `Co-Authored-By` trailers
  unless the user asks.

## STE-mini (bodies and PR paragraphs)

Write bodies and PR text in plain, simple English. Same subset as the
`jira-issue` skill, with one exception noted at the end:

- Active voice, simple present or simple past. No complex tenses.
- Short sentences: max 25 words. Shorter is better. Split long sentences.
- One idea per sentence. One instruction per sentence.
- One term per thing. No synonyms, no jargon, no idioms. Reuse the same word.
- No `-ing` clauses to carry order or cause. Write two plain sentences instead.
- Short paragraphs, one topic each.
- Exception: the commit subject is not a full STE sentence. It stays an
  imperative fragment, ~50 chars, no final period.

## PR descriptions: freeform, no headers, no PM template

Default: one or two short plain-text paragraphs. Freeform — what was found,
the problem, why it should be fixed. Like the user writes it, not a product
template.

- No headers by default. Applies to text you write, not to this file. Never
  use `#` or `##`. Use `####` only when a long description cannot stay
  readable without a split, max 1–2 per description.
- No generic sections: no `Summary`, `Why`, `Validation`, `Test plan`,
  no checklists, no `As a… I want… So that…`. No routine validation details.
  Use a structured format only when the user explicitly requests one.
- Same why-rule as commits: never narrate what the diff shows or restate the
  change as an action. Good: "DuckDB 1.5 rejects the virtual-hosted URL
  because it does not match the wildcard certificate, which failed
  `convert_details` after the upgrade." Wrong: "Configure the DuckDB S3
  secret to use path-style URLs." — that is the diff, spoken aloud.
- Before posting, run the subtraction test against the diff.

## Posting mechanics

Pass multi-line text with real newlines, never `\n` escapes. Write to a file
and pass it whole, or use a quoted heredoc:

```bash
git commit -F - <<'EOF'
Subject line

Body paragraph wrapped at 72 characters.

Resolves: #123
EOF
```

```bash
gh pr create --body-file body.md   # or gh pr edit --body-file body.md
```

An inline `"para1\n\npara2"` stores the literal backslash-n text, which
renders as visible `\n\n`.

## Verify

In order:

```text
imperative → ≤72-char subject → capitalized → no period → blank line
→ optional 72-wrapped body → subtraction test passes → no closing
action → STE-mini sentences → no headers (#{1,2} absent, #### only if needed)
→ references at bottom → no literal \n escapes
```

Report only the broken rules, with a corrected version. Cheap history pass:

```bash
git log --format=%s | awk 'length > 72'
```

Empty output means every subject fits the hard cap.

## Diagrams (only when shape helps)

Default stays prose-only. Add one diagram maximum, after the why-paragraph,
only when the *why* has visual shape (before/after flow, state change,
request lifecycle). Pick the shape with the `ascii-diagrams` skill; skip it
when prose covers it in two lines.

- Commit bodies (terminal, no Markdown): ASCII in a fenced `text` block.
  Keep every line ≤72 columns, never re-wrap. Never in the subject.
- PR descriptions (GitHub): prefer ASCII in a `text` block — it survives
  copy-paste and plain-text renderers. Use Mermaid only for shapes that need
  rendering, such as branching graphs.

---

Imported from [divaltor/.dotfiles](https://github.com/divaltor/.dotfiles/blob/ee95046d60707a8a4e1ec72412b2aaa4e4e61ebc/.config/opencode/skills/commit-pr/SKILL.md).
