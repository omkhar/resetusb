# AGENTS.md

This file contains the canonical shared instructions for coding agents.
Edit this file directly.
`CLAUDE.md` imports this file. `GEMINI.md` points to this file.

Agent-native change gate: `.agents/skills/resetusb-change-gate/SKILL.md`

# resetusb Agent Control Plane

This document uses ASD-STE100 Simplified Technical English.

`README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `Makefile`, `scripts/`, and
`.github/workflows/` contain the executable repository contract.
Use these files as the authority. Do not add a second policy layer here.

Use `resetusb-change-gate` for every repository change.

Codex only: `.codex/config.toml` contains Codex-native model and delegation
guidance. Other agents ignore this paragraph.

Core invariants:

- Keep changes simple, focused, and easy to review.
- Keep each remote PR narrow. A human reviewer must understand its scope, behavior, and risk quickly.
- Put unrelated work in separate PRs.
- Preserve Linux-only assumptions and the existing safety messaging.
- Before closeout, remove internal notes, local paths, usernames, scratch artifacts, and repository waste from public files.

Control-plane layout:

- Canonical shared skills live in `.agents/skills/`.
- `.claude/skills` is a symbolic link to `.agents/skills`.
