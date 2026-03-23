#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SEMVER_RE = re.compile(r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SHA1_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
TIMESTAMP_RE = re.compile(r"^[0-9]{8}T[0-9]{6}Z$")
ARTIFACT_NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")


def fail(message: str) -> None:
    raise SystemExit(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_manifest(
    manifest: dict,
    *,
    repository: str,
    release_tag: str | None,
    source_digest: str | None,
    builder_digest: str | None,
    primary_artifacts_json: str | None,
    dist_dir: Path | None,
) -> None:
    require(
        set(manifest)
        == {
            "format_version",
            "release_tag",
            "source_digest",
            "builder_digest",
            "builder_workflow",
            "reproducible_inputs",
            "primary_artifacts",
        },
        "release manifest contains unexpected top-level keys",
    )
    require(manifest.get("format_version") == 2, "release manifest format_version must be 2")

    manifest_release_tag = manifest.get("release_tag")
    require(isinstance(manifest_release_tag, str) and SEMVER_RE.fullmatch(manifest_release_tag), "release manifest release_tag must be a semver tag")
    if release_tag is not None:
        require(manifest_release_tag == release_tag, "release manifest tag does not match the requested release tag")

    manifest_source_digest = manifest.get("source_digest")
    require(isinstance(manifest_source_digest, str) and SHA1_RE.fullmatch(manifest_source_digest), "release manifest source_digest must be a 40-character lowercase hex digest")
    if source_digest is not None:
        require(manifest_source_digest == source_digest, "release manifest source digest does not match the signed tag commit")

    manifest_builder_digest = manifest.get("builder_digest")
    require(isinstance(manifest_builder_digest, str) and SHA1_RE.fullmatch(manifest_builder_digest), "release manifest builder_digest must be a 40-character lowercase hex digest")
    if builder_digest is not None:
        require(manifest_builder_digest == builder_digest, "release manifest builder digest does not match the trusted builder workflow")

    expected_workflow = f"https://github.com/{repository}/.github/workflows/release-builder.yml@refs/heads/main"
    require(manifest.get("builder_workflow") == expected_workflow, "release manifest builder workflow does not match the trusted builder identity")

    reproducible_inputs = manifest.get("reproducible_inputs")
    require(isinstance(reproducible_inputs, dict), "release manifest reproducible_inputs must be a JSON object")
    require(set(reproducible_inputs) == {"source_date_epoch", "builder_base_image", "debian_snapshot_url", "debian_snapshot_timestamp", "debian_suite"}, "release manifest reproducible_inputs contains unexpected keys")
    source_date_epoch = reproducible_inputs.get("source_date_epoch")
    require(isinstance(source_date_epoch, int) and source_date_epoch >= 0, "release manifest source_date_epoch must be a non-negative integer")
    require(isinstance(reproducible_inputs.get("builder_base_image"), str) and reproducible_inputs["builder_base_image"], "release manifest builder_base_image must be a non-empty string")
    require(isinstance(reproducible_inputs.get("debian_snapshot_url"), str) and reproducible_inputs["debian_snapshot_url"].startswith(("http://", "https://")), "release manifest debian_snapshot_url must be an HTTP or HTTPS URL")
    require(isinstance(reproducible_inputs.get("debian_snapshot_timestamp"), str) and TIMESTAMP_RE.fullmatch(reproducible_inputs["debian_snapshot_timestamp"]), "release manifest debian_snapshot_timestamp must be a snapshot timestamp")
    require(isinstance(reproducible_inputs.get("debian_suite"), str) and reproducible_inputs["debian_suite"], "release manifest debian_suite must be a non-empty string")

    primary_artifacts = manifest.get("primary_artifacts")
    require(isinstance(primary_artifacts, dict) and primary_artifacts, "release manifest primary_artifacts must be a non-empty JSON object")

    if primary_artifacts_json is not None:
        expected_artifacts = json.loads(primary_artifacts_json)
        require(isinstance(expected_artifacts, list), "PRIMARY_ARTIFACTS_JSON must decode to a JSON list")
        require(sorted(primary_artifacts) == sorted(expected_artifacts), "release manifest artifacts do not match the staged primary artifacts")

    for artifact, metadata in primary_artifacts.items():
        require(isinstance(artifact, str) and ARTIFACT_NAME_RE.fullmatch(artifact), f"unexpected artifact name: {artifact}")
        require(isinstance(metadata, dict) and set(metadata) == {"sha256"}, f"release manifest entry for {artifact} must contain only sha256")
        require(isinstance(metadata.get("sha256"), str) and SHA256_RE.fullmatch(metadata["sha256"]), f"release manifest digest for {artifact} must be a lowercase sha256 hex string")

        if dist_dir is not None:
            artifact_path = dist_dir / artifact
            require(artifact_path.is_file(), f"missing staged artifact: {artifact_path}")
            require(sha256_file(artifact_path) == metadata["sha256"], f"release manifest digest mismatch for {artifact}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a resetusb release manifest.")
    parser.add_argument("--manifest", required=True, help="Path to the release manifest JSON file.")
    parser.add_argument("--repository", required=True, help="GitHub repository slug, for example omkhar/resetusb.")
    parser.add_argument("--release-tag")
    parser.add_argument("--source-digest")
    parser.add_argument("--builder-digest")
    parser.add_argument("--primary-artifacts-json")
    parser.add_argument("--dist-dir")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(isinstance(manifest, dict), "release manifest root must be a JSON object")

    dist_dir = Path(args.dist_dir) if args.dist_dir else None
    validate_manifest(
        manifest,
        repository=args.repository,
        release_tag=args.release_tag,
        source_digest=args.source_digest,
        builder_digest=args.builder_digest,
        primary_artifacts_json=args.primary_artifacts_json,
        dist_dir=dist_dir,
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
