# Review Issue #__NUMBER__

You are reviewing an implementation that was completed by an automated build loop. What do you think of it? Is it correct? Is it complete? What's the riskiest part? If something feels off but you're not sure why, say that too.

Your job is to find real problems — not to nitpick style or suggest improvements to working code.

## Step 1: Read the spec

Run `.claude/skills/project-management/view-issue __NUMBER__` to read the original issue.

## Step 2: Find the implementing commit

The close comment says "Implemented in <sha>". Search all comments for it (don't assume it's the last one):

```bash
gh issue view __NUMBER__ --repo "$(git remote get-url origin | sed 's|.*github.com[:/]||; s|\.git$||')" --json comments --jq '.comments[] | select(.body | test("Implemented in [a-f0-9]")) | .body' | tail -1
```

If no comment contains a SHA, search git log:

```bash
git log --oneline --grep="#__NUMBER__" | head -5
```

## Step 3: Read the diff

Once you have the SHA, read the full diff and the changed files in context:

```bash
git show <sha> --stat
git show <sha>
```

For each changed file, also read the current version to understand surrounding context.

## Step 4: Review

Before going through the checklist: what's your gut reaction to this diff? What's the riskiest part of this change? Would you approve this if you were responsible for it shipping?

Now evaluate against these categories. Only flag genuine problems — things that are broken, dangerous, or fake. A working implementation that could be marginally better is NOT a problem.

### Correctness
Does it actually do what the spec says? Are edge cases handled? Does it break existing functionality?

### Hallucinations
Does the code reference methods, classes, APIs, gems, or configurations that don't exist in the codebase? Verify by searching — don't guess. This is the most common and most dangerous category.

### Shortcuts
Are there stubs, TODOs, placeholder implementations, or hardcoded values that should be dynamic? Incomplete implementations that look complete are worse than obviously incomplete ones.

### Security
Injection vulnerabilities, auth bypass, unescaped output, missing authorization checks, secrets in code. Only flag concrete vulnerabilities, not theoretical concerns.

### Tech debt
Patterns that will cause real pain: tight coupling that makes the next feature impossible, duplicated logic that will drift, missing database constraints that allow corrupt data. Skip aesthetic concerns.

### Test quality
Are tests actually testing the implementation, or just testing that Rails works? Do they cover the important edge cases from the spec? Are they testing behavior or implementation details?

## Step 5: File issues (high bar)

Only file issues for things that meet this bar: **"Will this cause a problem?"** — not "Would I have done it differently?"

For each real problem found, file an issue in the same milestone as the reviewed issue, then label it:

```bash
MILESTONE=$(gh issue view __NUMBER__ --repo "$(git remote get-url origin | sed 's|.*github.com[:/]||; s|\.git$||')" --json milestone --jq '.milestone.title // empty')
MS_FLAG=""; [[ -n "$MILESTONE" ]] && MS_FLAG="--milestone $MILESTONE"
NEW_ISSUE=$(.claude/skills/project-management/create-issue "Review #__NUMBER__: <problem summary>" --body "<description>" $MS_FLAG | sed 's/.*#\([0-9]*\).*/\1/')
gh issue edit "$NEW_ISSUE" --repo "$(git remote get-url origin | sed 's|.*github.com[:/]||; s|\.git$||')" --add-label "skinner:review"
```

## Step 6: Update CLAUDE.md learnings (high bar)

Most reviews should NOT add a learning. Only add one if the mistake is **likely to recur across multiple future issues** and **cannot be prevented by reading the code that now exists**.

A learning is worth adding when:
- It's about a tool/library/runtime gotcha that has no signal in the codebase (e.g., a PG version difference, a gem that moved out of stdlib)
- The same class of mistake has already happened more than once

A learning is NOT worth adding when:
- The fix is now in the code — future Claude can read the code and see the pattern
- It's a one-off bug specific to a single ticket (wrong argument order, missing require, typo)
- It's about how a specific API works — that's what docs are for
- It duplicates something already in CLAUDE.md conventions

Good learnings:
- "PG 17 split `pg_stat_bgwriter` into two views with renamed columns — version-gate collectors"
- "`insert_all` does not auto-set `created_at`/`updated_at` timestamps"

Bad learnings (don't add these):
- "Use `::ActionMailer::Base` inside `module Stratum`" — that's just how Ruby namespacing works
- "`button_link` takes text as first arg" — the fix is in the code now
- "Add `require 'net/http'`" — the require is in the code now

## Step 7: Mark as reviewed

After completing the review (whether or not issues were filed):

```bash
gh issue edit __NUMBER__ --repo "$(git remote get-url origin | sed 's|.*github.com[:/]||; s|\.git$||')" --add-label "skinner:reviewed"
```

## Rules

1. **Verify before flagging.** Search the codebase to confirm something is actually missing or broken before filing an issue. Don't guess.
2. **One issue per problem.** Don't bundle multiple unrelated problems into one issue.
3. **Be specific.** Issues should say exactly what's wrong and where, not vague concerns.
4. **No style issues.** Working code that follows different conventions is not a bug.
5. **No scope creep.** The implementation should match the spec. Don't file issues for features the spec didn't ask for.
6. **Learnings are expensive.** Every entry costs context window space on every future run. Only add learnings for recurring, undetectable-from-code gotchas. When in doubt, don't add it — the fix is in the code.
