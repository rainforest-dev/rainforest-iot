# Review guide

Pull requests here are reviewed by the subagents in `.claude/agents/review-*.md`.
The `Claude Review` workflow runs the ones the changed paths call for, checks their
findings and posts them as inline comments plus one summary. The loop runs the same
subagents before it opens a PR.

| Reviewer | Runs when the PR changes | Asks |
|---|---|---|
| `review-correctness` | anything | Does the change do what it says without breaking what it touches? |
| `review-blast-radius` | `ansible/**`, `modules/**`, `*.tf`, `configs/**` | If this goes wrong on the one Pi, what breaks in the house, and can the owner get back in remotely? |
| `review-exposure` | `ansible/**`, `modules/**`, `*.tf`, `configs/**`, any docs or example file | Can anyone reach something new? Does a secret or home-network detail land in this public repo? |

## Rules reviewers cite

- CLAUDE.md "Dependency Flow" (Prometheus CRDs before Loki ServiceMonitors)
- CLAUDE.md "Security Configuration" and "Security Considerations" (no privileged
  containers, specific capabilities, opt-in USB)
- CLAUDE.md "Service Ports"

## Severity

`🔴 blocking`: a change that can take DNS, SSH or the house's devices down without a
remote way back, data loss, a new exposure, or a secret in the repo.
`🟡 optional`: everything else.

## Not worth a comment

`terraform fmt` and YAML style, and anything in code the PR did not change.
Placeholders in docs are intentional.
