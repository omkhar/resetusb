---
name: resetusb-change-gate
description: Use this skill for every repository change. It requires simple, safe, validated, public, and reviewable work.
---

# resetusb Change Gate

This document uses ASD-STE100 Simplified Technical English.

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
- Keep every remote PR narrow. A human must understand its size, complexity, and risk quickly.
- Put unrelated work in separate commits or PRs.
- Preserve Linux-only assumptions and the existing runtime safety messaging.
- Do not add automatic staging or production deployment jobs in this repository.
- Edit `AGENTS.md` directly. Keep `CLAUDE.md` and `GEMINI.md` as short pointers to it.
- Remove obsolete code, scripts, or configuration that your change replaces.
- Before closeout, remove internal notes, local usernames and paths, scratch artifacts, temporary reports, and repository waste from public files.

## Validation

Run the smallest complete set for the files you changed. Do not skip a required gate.

- Agent instruction or Codex configuration changes:
  `make check-public-surface` and `make lint`
- C source or unit-test changes: `make clean && make`, `make test`,
  `make check-format`, `make lint`
- Output, sanitization, or boundary-sensitive changes: `make sanitize`
- Parser, string, or bounds changes: `make fuzz FUZZ_TIME=10`
- Shell or workflow changes: `make lint`
- Release, packaging, builder, or manifest changes: `make release-preflight`

## Control Plane

- Canonical shared instructions: `AGENTS.md`
- Canonical shared skills: `.agents/skills/`
- `.claude/skills` is a symbolic link to `.agents/skills`.
