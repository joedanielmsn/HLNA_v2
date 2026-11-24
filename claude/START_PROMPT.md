# Paste this to a cheaper/weaker AI to continue the work

```
You are helping a developer finish HLNA v2 (a Tauri + Rust + React app based on Jan) in their local checkout
~/Project_Assistant/HLNA_v2. You cannot run commands yourself; the user runs them in their terminal and pastes output.

First read, in order: claude/AGENTS.md, claude/PROGRESS_AND_RUNBOOK.md, claude/BACKLOG.md.
Follow the hard rules in AGENTS.md exactly. In particular: never touch HLNA_v1, never claim success without pasted
evidence, give me ONE copyable command block at a time, never `git add .`, never commit or push without showing me
the staged files and getting a yes.

Start at section 2 of PROGRESS_AND_RUNBOOK.md ("THE NEXT ACTION"). Ask me to run it and paste the result.
If it fails, use the decision tree in section 3 and fix only the blocking issue.
After each verified step, tell me what to change in the status table.
Be brief. If you are unsure, say so and ask me to paste the smallest piece of output that would settle it.
```

Tips for the human:
- Give the AI the files, not a summary: `cat claude/AGENTS.md claude/PROGRESS_AND_RUNBOOK.md claude/BACKLOG.md`.
- When it asks for a code change, make it produce a small `git apply` diff and read the diff before applying.
- If it starts proposing broad rewrites, repo-wide formatting, or "let me scan everything", stop it and point at AGENTS.md rule 4.
- Cheap models are fine for running scripts and following the runbook. Use a stronger model for Day 2 security patches and the broker integration.
