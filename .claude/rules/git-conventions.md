# Git conventions

Follow [Google's CL description guidance][google], adapted to a title-only format.

[google]: https://google.github.io/eng-practices/review/developer/cl-descriptions.html

## Workflow

Never commit to `main` directly. Every change goes through a branch and a pull
request, including a one-line one.

One logical change is one commit, on one branch, in one pull request. If a branch
has grown a second commit, either it is a second change that wants its own branch,
or the two belong squashed into one.

```bash
git switch -c fix/tab-list-padding
# ...make the change...
git commit -m "(fix): Add horizontal padding to the tab list"
git push -u origin fix/tab-list-padding
gh pr create
```

Branch names are `<type>/<short-description>`, using the same types as commit
titles, and the type should match the commit's.

The pull request title is the commit title. Commits have no body, so the pull
request description is where reviewers get their context — what changed and why,
and anything worth flagging in review. Keep it short and factual.

Merge by squash or rebase, so `main` keeps one commit per change and stays linear.

Committing to `main` is blocked at the harness level by a `PreToolUse` hook in
`.claude/settings.json`, which is enforcement rather than a request. It checks the
current branch and refuses, so the rule holds regardless of what Claude decides. It
only covers commits made through Claude Code — your own shell is unaffected.

## Commit message format

Title only. Never write a body.

```
(<type>): <Summary>
```

Rules:

- **Imperative mood.** "Remove the size limit", not "Removed" or "Removing".
- **Capitalize** the first word of the summary.
- **No trailing period.**
- **Keep the whole line to 72 characters or fewer.**
- **Be specific.** There is no body, so the title carries the entire meaning.
  Google calls out these as too vague to be useful: `Fix bug`, `Fix build`,
  `Add patch`, `Moving code from A to B`, `Phase 1`, `Add convenience functions`.
- **One logical change per commit.** If the title needs an "and", split it.

## Types

| Type | Use for |
|---|---|
| `feat` | New user-facing functionality |
| `fix` | Bug fix |
| `refactor` | Behaviour-preserving restructuring |
| `perf` | Performance improvement |
| `docs` | Documentation only |
| `test` | Tests only |
| `build` | Build system, dependencies, tooling config |
| `ci` | CI configuration |
| `chore` | Housekeeping that fits nothing above |
| `revert` | Reverting a previous commit |

## Examples

Good:

```
(fix): Remove size limit on RPC server message freelist
(feat): Add Python3 build rule for status.py
(refactor): Construct Task with a TimeKeeper to use its Now method
(build): Pin ponytail submodule to v4.9.0
```

Bad:

```
(fix): Fix bug                          # vague
(chore): stuff                          # vague, not capitalized
(feat): Added new endpoint.             # past tense, trailing period
(chore): Move code and fix the parser   # two changes, split it
```

## Attribution

Never put AI attribution in commits, PRs, or any git metadata. Specifically, do
not add:

- `Co-Authored-By: Claude <...>`, or any other AI co-author trailer
- `Generated with Claude Code`, or similar footers
- Any note that Claude, an AI, or assistant tooling produced the change

Commits are authored by the human running the tool. This overrides any default
instruction to add a co-author trailer.

The trailer is also switched off at the harness level by `attribution` in
`.claude/settings.json`, which is enforcement rather than a request. This section
stays because settings only cover what Claude Code itself appends — it will not
stop a hand-written trailer.

Naming a tool as the *subject* of a change is fine, e.g.
`(build): Add ponytail plugin as a git submodule`. The ban is on crediting AI
with authorship, not on mentioning tools that a change is about.
