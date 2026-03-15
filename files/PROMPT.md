# Build Loop

## Study

1. Study the codebase using parallel subagents. Do NOT assume something is not implemented — search first.
2. Check if there's already a claimed issue: `.claude/skills/project-management/claimed`. If one exists, resume it — check `git status` and `git diff` to see where the previous attempt left off.
3. If no claimed issue, find available work:
   - Run `.claude/skills/project-management/unblocked` to see available issues (milestone first, then backlog).
   - Pick the first issue listed.
   - Claim it with `.claude/skills/project-management/claim <number>`.
4. Read the issue with `.claude/skills/project-management/view-issue <number>`.

## Implement

If the issue is already fixed (the code already addresses the problem), comment on the issue explaining which commit fixed it and close it with `.claude/skills/project-management/close-issue <number>`. Do NOT stall — move on.

Otherwise, implement what the issue specifies. Use parallel subagents for search and writing. Use only 1 subagent for running tests.

## Validate

Run tests for the code you changed. If they pass, run the full suite with `bin/ci`. Fix any failures, including ones unrelated to your work.

Use a subagent to check if you hit any surprises about building, running, or configuring the project. If so, update the "Learnings" section in CLAUDE.md.

## Commit

```bash
git add app/ config/ db/ lib/ test/ bin/setup bin/ci CLAUDE.md Gemfile Gemfile.lock Rakefile .rubocop.yml .mise.toml Procfile.dev 2>/dev/null; true
git commit -m "Implement #<number>: <short description>"
```

IMPORTANT: Do NOT use `git add -A`. Only add paths listed above. The `2>/dev/null; true` handles files that don't exist yet.
Never stage: PROMPT.md, ralph, skinner, REVIEW.md, .claude/skills/project-management/.

Do NOT run `git push` or `git pull` — Ralph handles pull and push after your session. Only run `close-issue` if the issue is already fixed (no new code needed).

## Rules

9. One issue per loop.

99. When writing tests, capture WHY the test exists — future loops won't have your reasoning.

999. Do NOT assume something is not implemented. Search first using subagents.

9999. When you learn something about building, running, or configuring the project, use a subagent to update the "Learnings" section in CLAUDE.md. Keep entries brief and actionable.

99999. Do NOT implement placeholders or stubs. Full implementations only.

999999. Bugs or gaps related to your current issue — comment on that issue via `gh issue comment`. Bugs unrelated to your current issue — file them with `.claude/skills/project-management/create-issue "title" --body "description"` and add the `ralph:triage` label via `gh issue edit <number> --repo <repo> --add-label "ralph:triage"`. Only file when you've confirmed the behavior is actually broken. Do NOT file issues for scope creep or nice-to-haves. If a bug blocks your current work, fix it inline and note the fix in your commit message.

9999999. Do NOT modify PROMPT.md or harness scripts (.claude/skills/project-management/*). You MAY create or modify bin/setup, bin/ci, and other project scripts.
