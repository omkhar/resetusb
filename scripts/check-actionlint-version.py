#!/usr/bin/env python3

from __future__ import annotations

import re
import sys


MINIMUM = (1, 7, 10)


def parse_version(raw: str) -> tuple[int, int, int]:
    numbers = [int(part) for part in re.findall(r"\d+", raw)]
    padded = (numbers + [0, 0, 0])[:3]
    return tuple(padded)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-actionlint-version.py <version>", file=sys.stderr)
        return 2

    version = sys.argv[1]
    if parse_version(version) < MINIMUM:
        print(
            f"actionlint {version} is too old; need >= "
            f"{MINIMUM[0]}.{MINIMUM[1]}.{MINIMUM[2]}",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
