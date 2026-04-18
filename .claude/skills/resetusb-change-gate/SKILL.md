---
name: resetusb-change-gate
description: Use this skill for every change in this repository, including code, docs, tests, workflows, release tooling, and repo hygiene work. It enforces resetusb's simplicity, safety, validation, public-repo hygiene, and reviewability expectations.
---

# resetusb Change Gate

If guidance here conflicts with executable repo checks or repository policy
documents, follow the executable checks and the repository documents.

## Read First

- `README.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `Makefile`
- Any touched file under `scripts/` or `.github/workflows/`

## Priorities

1. Simplicity
2. Correctness
3. Linting and clean validation
4. Appropriate test coverage
5. Security
6. Performance
7. Current idiomatic correctness

## Working Rules

- Keep changes small, reviewable, and tightly scoped.
- When pushing work remotely, keep every PR narrow enough for a human to reason
  about the size, complexity, and risk quickly.
- Split unrelated work into separate commits or PRs instead of batching it.
- Preserve Linux-only assumptions and the existing runtime safety messaging.
- Do not add automatic staging or production deployment jobs in this repository.
- Do not hand-edit generated `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or
  `.claude/skills/*`. Edit the canonical sources and rerender.
- Remove obsolete code, scripts, or configuration that your change replaces.
- Before closeout, strip internal-only notes, local usernames and paths,
  scratch artifacts, temporary reports, and repository detritus from public
  surfaces.

## Validation

Run the smallest complete set for the files you touched, but do not skip the
required gates.

- All changes: `make lint`
- C source or unit-test changes: `make clean && make`, `make test`,
  `make check-format`
- Output, sanitization, or boundary-sensitive changes: `make sanitize`
- Parser, string, or bounds changes: `make fuzz FUZZ_TIME=10`
- Workflow changes: `actionlint`
- Release, packaging, builder, or manifest changes: `make release-preflight`

## Control Plane

- Canonical shared instructions: `agent-control-plane/project-instructions.md`
- Canonical shared skills: `.agents/skills/`
- Generated Claude mirror: `.claude/skills/`
- Regenerate after editing canonical sources:
  `python3 scripts/render-agent-control-plane.py`
