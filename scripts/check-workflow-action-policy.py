#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

import yaml


GITHUB_ACTION = re.compile(
    r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*@([0-9A-Fa-f]{40})$"
)
DOCKER_ACTION = re.compile(r"^docker://[^\s@]+@sha256:[0-9A-Fa-f]{64}$")


class PolicyError(ValueError):
    pass


def require_mapping(value: Any, name: str) -> dict[Any, Any]:
    if not isinstance(value, dict):
        raise PolicyError(f"{name} must be a mapping")
    return value


def require_immutable_action(value: Any) -> str:
    if (
        not isinstance(value, str)
        or not value
        or "\\" in value
        or any(char.isspace() for char in value)
    ):
        raise PolicyError("Each uses value must be one action reference")
    if value.startswith("./"):
        if any(segment in {"", ".", ".."} for segment in value[2:].split("/")):
            raise PolicyError("Local action paths must not use dot segments")
        return value
    if GITHUB_ACTION.fullmatch(value):
        action_path = value.rpartition("@")[0]
        if any(segment in {".", ".."} for segment in action_path.split("/")):
            raise PolicyError("GitHub action paths must not use dot segments")
        return value
    if DOCKER_ACTION.fullmatch(value):
        return value
    raise PolicyError("Each external action must use an immutable revision")


def check_workflow(path: Path, require_codeql_pair: bool) -> None:
    try:
        # BaseLoader keeps GitHub job identifiers such as "yes" and "true" distinct.
        document = yaml.load(path.read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise PolicyError("The workflow YAML is not valid") from error

    workflow = require_mapping(document, "The workflow")
    jobs = require_mapping(workflow.get("jobs"), "The jobs value")
    codeql_phases: list[tuple[Any, str, str]] = []

    for job_id, raw_job in jobs.items():
        job = require_mapping(raw_job, f"Job {job_id}")
        if "uses" in job:
            require_immutable_action(job["uses"])

        raw_steps = job.get("steps", [])
        if not isinstance(raw_steps, list):
            raise PolicyError(f"The steps value in job {job_id} must be a list")

        for step_index, raw_step in enumerate(raw_steps):
            step = require_mapping(raw_step, f"Step {step_index} in job {job_id}")
            if "uses" not in step:
                continue
            action = require_immutable_action(step["uses"])
            action_path, separator, revision = action.rpartition("@")
            normalized_path = action_path.casefold()
            if separator and normalized_path in {
                "github/codeql-action/init",
                "github/codeql-action/analyze",
            }:
                phase = normalized_path.rsplit("/", 1)[1]
                if "if" in job or "if" in step:
                    raise PolicyError("CodeQL jobs and steps must not be conditional")
                if "needs" in job:
                    raise PolicyError("The CodeQL job must not depend on another job")
                if "continue-on-error" in job or "continue-on-error" in step:
                    raise PolicyError("CodeQL jobs and steps must not ignore failures")
                if phase == "analyze":
                    inputs = require_mapping(step.get("with", {}), "CodeQL analyze inputs")
                    input_names = {str(name).casefold() for name in inputs}
                    if input_names & {"expect-error", "skip-queries", "upload"}:
                        raise PolicyError("CodeQL analyze must run queries and upload results")
                codeql_phases.append((job_id, phase, revision.lower()))

    if not codeql_phases and not require_codeql_pair:
        return

    if len(codeql_phases) != 2:
        raise PolicyError("The workflow must have one CodeQL init step and one analyze step")

    init_phase, analyze_phase = codeql_phases
    if init_phase[1] != "init" or analyze_phase[1] != "analyze":
        raise PolicyError("The CodeQL init step must occur before the analyze step")
    if init_phase[0] != analyze_phase[0]:
        raise PolicyError("The CodeQL init and analyze steps must be in the same job")
    if init_phase[2] != analyze_phase[2]:
        raise PolicyError("The CodeQL init and analyze steps must use the same revision")


def main() -> int:
    arguments = sys.argv[1:]
    require_codeql_pair = False
    if arguments and arguments[0] == "--require-codeql-pair":
        require_codeql_pair = True
        arguments = arguments[1:]
    if len(arguments) != 1:
        print(
            "usage: check-workflow-action-policy.py [--require-codeql-pair] WORKFLOW",
            file=sys.stderr,
        )
        return 2

    try:
        check_workflow(Path(arguments[0]), require_codeql_pair)
    except PolicyError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
