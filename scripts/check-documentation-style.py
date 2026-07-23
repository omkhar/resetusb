#!/usr/bin/env python3

from __future__ import annotations

import re
import subprocess
from pathlib import Path


DOCUMENT_SUFFIXES = frozenset({".md", ".markdown", ".rst", ".txt", ".8"})
STE_DECLARATION = "ASD-STE100 Simplified Technical English"
MAX_DESCRIPTIVE_SENTENCE_WORDS = 25
MAX_PROCEDURAL_SENTENCE_WORDS = 20
INLINE_CODE = re.compile(r"`[^`]*`")
LINK_TARGET = re.compile(r"\]\([^)]*\)")
URL = re.compile(r"https?://\S+")
WORD = re.compile(r"[A-Za-z0-9]+(?:[-'][A-Za-z0-9]+)*")
SENTENCE_END = re.compile(r"[.!?]+(?:\s+|$)")
LIST_ITEM = re.compile(r"^(?:[-+*]|[0-9]+\.)\s+")
TROFF_INLINE = re.compile(r"^\.(?:B|BR|I|IR|RB|RI)\b")
MARKDOWN_HEADING = re.compile(r"^#{1,6}\s+")
TROFF_HEADING = re.compile(r'^\.(?:SH|SS)\s+(.*)$')
# ASD-STE100 Issue 9, rule 3.5.
UNAPPROVED_ING = re.compile(
    r"\b(?:including|participating|rebuilding|requesting|responding|using)\b|"
    r"\b(?:after|before|by|when|while|without)\s+[a-z]+ing\b",
    re.IGNORECASE,
)
# ASD-STE100 Issue 9, rule 4.2.
CONTRACTION = re.compile(
    r"\b(?:ain|aren|can|couldn|didn|doesn|don|hadn|hasn|haven|isn|"
    r"mightn|mustn|needn|shan|shouldn|wasn|weren|won|wouldn)['’]t\b|"
    r"\b(?:he|how|i|it|let|she|that|there|they|we|what|when|where|who|"
    r"why|you)['’](?:d|ll|m|re|s|ve)\b",
    re.IGNORECASE,
)
PASSIVE = re.compile(
    r"\b(?:am|is|are|was|were|be|been|being|will be|must be|can be|may be|should be)\s+"
    r"(?:(?:not|also|always|currently|only|explicitly|privately|already)\s+)*"
    r"(?:(?:[a-z]+-)*[a-z]+ed|built|cut|done|found|given|kept|known|made|read|reset|run|seen|sent|set|shown|taken|told|used|written)\b",
    re.IGNORECASE,
)
CONTROLLED_MEANINGS = {
    "acceptable": "permitted",
    "re-enumerate": "enumerate again",
    "re-enumerated": "enumerated again",
    "reprobe": "probe again",
    "reprobed": "probed again",
    "utilize": "use",
    "utilized": "used",
    "via": "through",
}
CONTROLLED_WORD = re.compile(
    r"\b(" + "|".join(map(re.escape, CONTROLLED_MEANINGS)) + r")\b", re.IGNORECASE)
INSTRUCTION_VERBS = tuple(
    "add address attach avoid build bump check choose clone compare confirm "
    "copy create cut delete describe document edit explain follow format include "
    "increase install inspect keep limit list make open plan preserve publish push "
    "read regenerate remove report request review rerun resolve run set sign split "
    "start strip submit summarize test update use verify write".split()
)
INSTRUCTION_VERB_PATTERN = "(?:" + "|".join(INSTRUCTION_VERBS) + ")"
COMBINED_INSTRUCTION_VERBS = tuple(verb for verb in INSTRUCTION_VERBS if verb != "build")
COMBINED_INSTRUCTION_VERB_PATTERN = "(?:" + "|".join(COMBINED_INSTRUCTION_VERBS) + ")"
INSTRUCTION_START = re.compile(
    rf"^(?:(?:then|please)\s+)?(?:do not\s+)?"
    rf"{INSTRUCTION_VERB_PATTERN}\b",
    re.IGNORECASE,
)
CONDITIONAL_INSTRUCTION = re.compile(
    rf"^(?:after|before|if|when)\b.*?,\s*"
    rf"(?:(?:then|please)\s+)?(?:do not\s+)?"
    rf"{INSTRUCTION_VERB_PATTERN}\b",
    re.IGNORECASE,
)
COMBINED_INSTRUCTION = re.compile(
    rf"(?<=\S)\s+(?:and|or|then)\s+(?:do not\s+)?"
    rf"{COMBINED_INSTRUCTION_VERB_PATTERN}\b",
    re.IGNORECASE,
)

def document_paths() -> tuple[Path, ...]:
    result = subprocess.run(
        ("git", "ls-files", "-z"), check=True, stdout=subprocess.PIPE, text=True)
    return tuple(
        Path(name) for name in result.stdout.split("\0")
        if name and Path(name).suffix.lower() in DOCUMENT_SUFFIXES
    )

def strip_syntax(text: str) -> str:
    text = INLINE_CODE.sub(" technical-name ", text)
    text = LINK_TARGET.sub("]", text)
    text = URL.sub(" technical-url ", text)
    return text.strip().lstrip("#>*-+0123456789. ")

def prose_units(document: str) -> list[tuple[int, str, bool]]:
    units: list[tuple[int, str, bool]] = []
    paragraph: list[str] = []
    paragraph_line = 1
    in_fence = False

    def flush() -> None:
        nonlocal paragraph
        if paragraph:
            units.append((paragraph_line, " ".join(paragraph), False))
            paragraph = []

    for line_number, line in enumerate(document.splitlines(), 1):
        stripped = line.strip()
        troff_heading = TROFF_HEADING.match(stripped)
        if stripped == ".EX":
            flush()
            in_fence = True
            continue
        if stripped == ".EE":
            in_fence = False
            continue
        if stripped.startswith("```") or stripped.startswith("~~~"):
            flush()
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if not stripped:
            flush()
        elif TROFF_INLINE.match(stripped):
            if not paragraph:
                paragraph_line = line_number
            paragraph.append("technical-name")
        elif MARKDOWN_HEADING.match(stripped):
            flush()
            units.append((line_number, stripped, True))
        elif troff_heading:
            flush()
            units.append((line_number, troff_heading.group(1).strip('"'), True))
        elif stripped.startswith("."):
            flush()
        elif stripped.startswith("|"):
            flush()
            for cell in stripped.strip("|").split("|"):
                units.append((line_number, cell, False))
        elif LIST_ITEM.match(stripped):
            flush()
            units.append((line_number, stripped, False))
        else:
            if not paragraph:
                paragraph_line = line_number
            paragraph.append(stripped)
    flush()
    return units

def is_procedural(sentence: str) -> bool:
    return bool(INSTRUCTION_START.search(sentence) or CONDITIONAL_INSTRUCTION.search(sentence))

def check_unit(line_number: int, raw: str, heading: bool = False) -> list[str]:
    prose = strip_syntax(raw)
    if not prose or re.fullmatch(r"[-:| ]+", prose):
        return []

    result: list[str] = []
    if any(mark in prose for mark in (";", "–", "—")):
        result.append(f"line {line_number} uses disallowed punctuation")
    for sentence in SENTENCE_END.split(prose):
        sentence = sentence.strip()
        if not sentence:
            continue
        ing_match = None if heading else UNAPPROVED_ING.search(sentence)
        if ing_match:
            result.append(f"line {line_number} uses a non-approved -ing form: "
                          f"{ing_match.group(0)!r}")
        contraction_match = CONTRACTION.search(sentence)
        if contraction_match:
            result.append(f"line {line_number} uses a contraction: "
                          f"{contraction_match.group(0)!r}")
        controlled_match = CONTROLLED_WORD.search(sentence)
        if controlled_match:
            word = controlled_match.group(1).lower()
            result.append(f"line {line_number} uses non-controlled word {word!r}; "
                          f"use {CONTROLLED_MEANINGS[word]!r}")
        # ASD-STE100 Issue 9, rule 8.6 counts a complete heading as one word.
        count = 1 if heading else len(WORD.findall(sentence))
        procedural = is_procedural(sentence)
        maximum = MAX_PROCEDURAL_SENTENCE_WORDS if procedural else MAX_DESCRIPTIVE_SENTENCE_WORDS
        if count > maximum:
            result.append(f"line {line_number} has a {count}-word sentence "
                          f"(maximum {maximum})")
        if procedural and COMBINED_INSTRUCTION.search(sentence):
            result.append(f"line {line_number} has more than one instruction: "
                          f"{sentence!r}")
        if PASSIVE.search(sentence):
            result.append(f"line {line_number} has a passive-voice pattern: {sentence!r}")
    return result

def findings(document: str) -> list[str]:
    result: list[str] = []
    for line_number, unit, heading in prose_units(document):
        result.extend(check_unit(line_number, unit, heading))
    return result

def self_test() -> None:
    invalid = (
        ("Before using the tool, read the guide.", "non-approved -ing form"),
        ("The list has hubs, including root hubs.", "non-approved -ing form"),
        ("Before opening the cover, read the guide.", "non-approved -ing form"),
        ("Do not reset it by hand because it isn't safe.", "contraction"),
        ("Reports will be handled by the maintainer.", "passive-voice"),
        ("The device is reset by the program.", "passive-voice"),
        ("## Reports Are Reviewed", "passive-voice"),
        ('.SH "Reports Are Reviewed"', "passive-voice"),
        ("Run the test; then read the result.", "disallowed punctuation"),
        ("Temporary USB disruption is acceptable.", "non-controlled word"),
        ("Run the complete release preflight with all locked package images before "
         "publication during every maintenance window for each supported platform now.",
         "maximum 20"),
        ("Run the test and inspect the output.", "more than one instruction"),
        ("Run the test or inspect the output.", "more than one instruction"),
        ("Copy the archive and delete the source.", "more than one instruction"),
        ("This descriptive sentence contains more than twenty five words because it adds "
         "unnecessary text that makes the statement difficult for all readers to "
         "understand correctly and efficiently.", "maximum 25"),
    )
    for sample, expected in invalid:
        sample_findings = findings(sample)
        if not any(expected in finding for finding in sample_findings):
            raise SystemExit(f"style self-test accepted invalid prose: {sample} "
                             f"(expected {expected!r}, got {sample_findings!r})")
    if findings("Run the test. Then inspect the output."):
        raise SystemExit("style self-test rejected valid prose")
    if findings("# Packaging and Testing"):
        raise SystemExit("style self-test rejected a technical heading")
    long_heading = ("# Resetusb Device Build Test Release Package Runtime Security Source "
                    "Output Error Function Limit Tool System Archive Code Program Input Result "
                    "Failure Check Document Rule Text USB Linux Root Device")
    if findings(long_heading):
        raise SystemExit("style self-test counted heading words separately")
    troff_units = prose_units("Use\n.B tool\nonly for recovery.")
    if troff_units != [(1, "Use technical-name only for recovery.", False)]:
        raise SystemExit("style self-test split an inline troff sentence")

def main() -> int:
    self_test()
    failed = False
    for path in document_paths():
        document = path.read_text(encoding="utf-8")
        if STE_DECLARATION not in document:
            print(f"{path}:missing {STE_DECLARATION} declaration")
            failed = True
        for finding in findings(document):
            print(f"{path}:{finding}")
            failed = True
    return int(failed)

if __name__ == "__main__":
    raise SystemExit(main())
