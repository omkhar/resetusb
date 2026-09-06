# resetusb function reference

This document uses ASD-STE100 Simplified Technical English.

This reference describes each non-test function in the program and repository automation. Test helpers are not product interfaces.

## C program

| Function | Input | Result and failure |
| --- | --- | --- |
| `ops_complete` | A `resetusb_ops` pointer. | Returns true only when the pointer and all required callbacks are non-null. |
| `safe_error_name` | An operations table and a `libusb` error code. | Returns callback text. Returns `unknown` when the callback returns null. |
| `error_code_from_ssize` | A signed device-list result. | Converts the value to `int`. Returns `LIBUSB_ERROR_OTHER` when the value is outside the `int` range. |
| `sanitize_product_name` | A null-terminated product-name buffer. | Changes each non-printable byte to `?`. A null pointer has no effect. |
| `resetusb_run` | Operations, user IDs, and output streams. | Validates inputs and privileges. It enumerates devices, attempts resets, releases resources, and returns 0 only after complete success. |
| `main` | No C arguments. | Calls `resetusb_run` with the real operations and process streams. The program ignores operating-system arguments. |

`resetusb_ops` is an internal test seam. It is not a stable library API. See [LIMITATIONS.md](LIMITATIONS.md) for failure paths.

## Python automation

| File and function | Input | Result and failure |
| --- | --- | --- |
| `check-actionlint-version.py: parse_version` | Version text. | Returns the first three numeric parts. Missing parts become zero. |
| `check-actionlint-version.py: main` | One version argument. | Returns 0 for a supported version, 1 for an old version, and 2 for incorrect use. |
| `check-documentation-style.py: document_paths` | No arguments. | Returns the tracked documentation paths. A Git error stops the script. |
| `check-documentation-style.py: strip_syntax` | One text unit. | Returns prose without inline code, link targets, URLs, or Markdown prefixes. |
| `check-documentation-style.py: prose_units` | Document text. | Returns prose units, heading states, and source line numbers. It skips fenced code and troff example blocks. |
| `check-documentation-style.py: flush` | Current paragraph state. | Adds pending paragraph text to the current unit list. |
| `check-documentation-style.py: is_procedural` | One sentence. | Returns true when the sentence starts an instruction directly or after a condition. |
| `check-documentation-style.py: check_unit` | A line number, text unit, and heading state. | Returns the style findings for one unit. It counts a heading as one word. |
| `check-documentation-style.py: findings` | Document text. | Returns all style findings for the document. |
| `check-documentation-style.py: self_test` | No arguments. | Stops when an invalid sample passes or a valid sample fails. |
| `check-documentation-style.py: main` | Tracked documents. | Runs self-tests and document checks. Returns 1 after a declaration or style failure. |
| `check-workflow-action-policy.py: require_mapping` | A value and a name. | Returns the mapping. A value that is not a mapping stops the check. |
| `check-workflow-action-policy.py: require_immutable_action` | One `uses` value. | Returns a valid immutable action reference. A mutable or invalid reference stops the check. |
| `check-workflow-action-policy.py: check_workflow` | A workflow path and a pair requirement. | Validates each action reference. Validates the CodeQL phase pair when required or present. A violation stops the check. |
| `check-workflow-action-policy.py: main` | An optional pair flag and one workflow argument. | Returns 0 for a valid workflow, 1 for a violation, and 2 for incorrect use. |
| `release-builder.yml: load_builder_lock` | The release-builder lock path. | Returns valid key-value entries. It ignores blank lines and comments. An invalid entry stops the workflow step. |
| `render-agent-control-plane.py: build_agent_doc` | A file name, skill path, and shared text. | Returns one generated agent document. |
| `render-agent-control-plane.py: write_if_changed` | A path and text. | Writes changed text and returns true. Returns false when text is equal. |
| `render-agent-control-plane.py: collect_tree` | A directory. | Returns file data by relative path. A missing directory gives an empty map. |
| `render-agent-control-plane.py: expected_agent_docs` | No arguments. | Returns the expected generated agent documents. A read error stops the script. |
| `render-agent-control-plane.py: expected_claude_skill_payload` | No arguments. | Returns the canonical skill tree for the Claude mirror. |
| `render-agent-control-plane.py: validate_canonical_inputs` | No arguments. | Stops when required instructions or the required skill are missing or empty. |
| `render-agent-control-plane.py: render` | No arguments. | Writes generated agent documents, replaces the Claude skill mirror, and returns changed paths. |
| `render-agent-control-plane.py: check` | No arguments. | Returns 0 when generated files match. Returns 1 and reports each mismatch otherwise. |
| `render-agent-control-plane.py: parse_args` | Process arguments. | Returns the parsed `--check` state. Invalid arguments stop through `argparse`. |
| `render-agent-control-plane.py: main` | Process arguments. | Selects check or render mode and returns its status. |
| `validate-release-manifest.py: fail` | Error text. | Stops validation with the text. |
| `validate-release-manifest.py: require` | A condition and error text. | Has no result when true. Calls `fail` when false. |
| `validate-release-manifest.py: sha256_file` | A file path. | Returns the SHA-256 digest. A read error stops validation. |
| `validate-release-manifest.py: validate_manifest` | A manifest and expected release values. | Validates schema, identities, inputs, artifacts, and optional local files. A mismatch stops validation. |
| `validate-release-manifest.py: main` | Paths and expected values. | Loads JSON, calls `validate_manifest`, and returns 0 after success. |

## Shell automation

Shell functions stop their script when a required command, value, file, digest, platform, or test result is not valid.

| File and function | Input | Result or limit |
| --- | --- | --- |
| `build-release-artifacts.sh: resolve_source_date_epoch` | An explicit time or Git state. | Prints a numeric source time. Requires an explicit value without Git metadata. |
| `build-release-artifacts.sh: resolve_short_sha` | `GITHUB_SHA` or Git state. | Prints 12 commit characters. Prints `unknown` when neither source is available. |
| `build-release-artifacts.sh: normalize_tree_timestamps` | A staging tree. | Sets all tree times to `SOURCE_DATE_EPOCH`. |
| `build-release-artifacts.sh: require_cmd` | A command name. | Requires the command on `PATH`. |
| `build-release-artifacts.sh: validate_single_line_value` | A name and value. | Rejects empty or multi-line metadata. |
| `build-release-artifacts.sh: validate_regex_value` | A name, value, and pattern. | Requires single-line metadata that matches the pattern. |
| `build-release-artifacts.sh: canonicalize_existing_dir` | An absolute directory. | Prints its physical path. |
| `build-release-artifacts.sh: canonicalize_cleanup_dir` | An absolute cleanup path. | Prints a safe canonical path. Rejects root and relative components. |
| `build-release-artifacts.sh: validate_cleanup_dir` | A name and cleanup path. | Allows only a descendant of the source root, `TMPDIR`, or `/tmp`. Rejects each root itself. |
| `build-release-artifacts.sh: expect_non_root_error` | A log path and command. | Requires a non-root failure with `Must be root`. |
| `build-release-artifacts.sh: run_binary_test` | An architecture and two binaries. | Runs unit and non-root tests. Uses QEMU when required. |
| `build-release-artifacts.sh: build_binary` | `amd64`, `arm64`, or `armv7`. | Builds, tests, and stages one executable. |
| `build-release-artifacts.sh: create_tarball` | A supported architecture. | Creates one normalized generic archive with the binary and documents. |
| `build-release-artifacts.sh: create_deb_package` | A distribution and architecture. | Creates one normalized DEB package. |
| `build-release-artifacts.sh: create_rpm_package` | `amd64`. | Creates one normalized Fedora RPM. Releases create RPMs only for `amd64`. |
| `build-release-artifacts.sh: write_checksums` | The distribution directory. | Writes one `.sha256` file for each primary artifact. |
| `build-release-artifacts.sh: main` | Release state and optional version. | Validates tools and paths, builds all artifacts, and writes checksums. |
| `check-documentation-contract.sh: require_text` | A file and literal text. | Requires the text in the file. |
| `check-documentation-contract.sh: reject_text` | A file and literal text. | Rejects obsolete or incorrect text. |
| `check-documentation-contract.sh: compare_inventory` | A name and two inventories. | Requires the source and documented inventories to be equal. |
| `check-release-security-contract.sh: require_literal` | A file and literal text. | Requires the text in the file. |
| `check-release-security-contract.sh: forbid_literal` | A file and literal text. | Rejects the text in the file. |
| `check-release-security-contract.sh: require_digest_ref` | A file and an image prefix. | Requires a digest-pinned reference with the prefix in the file. |
| `check-release-security-contract.sh: require_literal_after` | A file, marker, text, and line limit. | Requires the text in the limited section after the marker. |
| `check-reviewable-pr.sh: require_integer` | A name and value. | Accepts a non-negative integer. |
| `release-preflight.sh: require_cmd` | A command name. | Requires the command on `PATH`. |
| `release-preflight.sh: validate_image_ref` | A name and image reference. | Accepts only permitted image-reference characters. |
| `release-preflight.sh: normalize_arch` | A machine architecture. | Prints `amd64` or `arm64`. Rejects other architectures. |
| `release-preflight.sh: resolve_prefight_platform` | Docker and host platform data. | Selects a supported Linux builder platform. |
| `release-preflight.sh: cleanup` | A temporary path. | Removes only the registered preflight file. |
| `run-package-smoke.sh: require_cmd` | A command name. | Requires the command on `PATH`. |
| `run-package-smoke.sh: validate_image_ref` | A name and image reference. | Accepts only permitted image-reference characters. |
| `run-package-smoke.sh: resolve_source_git_sha` | Repository state or `GITHUB_SHA`. | Prints the source commit. Requires `GITHUB_SHA` without Git metadata. |
| `run-package-smoke.sh: resolve_source_date_epoch` | An explicit time or Git state. | Prints a numeric source time. Requires an explicit value without Git metadata. |
| `test-package-integration.sh: resolve_arch_platform` | An artifact architecture. | Prints the Docker platform. |
| `test-package-integration.sh: resolve_deb_arch` | An artifact architecture. | Prints the Debian architecture. |
| `test-package-integration.sh: resolve_rpm_arch` | An artifact architecture. | Prints the RPM architecture. |
| `test-package-integration.sh: resolve_binfmt_arch` | An artifact architecture. | Prints the `binfmt` architecture or an empty line. |
| `test-package-integration.sh: platform_support_was_verified` | An architecture. | Returns success when this run already probed the platform. |
| `test-package-integration.sh: mark_platform_support_verified` | An architecture. | Records a successful platform probe. |
| `test-package-integration.sh: validate_locked_image_ref` | A lock name and image reference. | Requires one digest-pinned container reference. |
| `test-package-integration.sh: load_package_test_image_lock` | The image lock file. | Loads and validates all package-test image references. |
| `test-package-integration.sh: resolve_package_test_image` | A distribution, channel, and architecture. | Prints the matching locked image. |
| `test-package-integration.sh: require_artifact_version` | An artifact version. | Requires the expected artifact version syntax. |
| `test-package-integration.sh: probe_platform_support` | An architecture and image. | Runs a Docker platform probe and returns its status. |
| `test-package-integration.sh: ensure_platform_support` | An architecture and image. | Probes once. Stops when Docker cannot run the platform. |
| `test-package-integration.sh: with_extracted_tarball` | An archive and callback. | Extracts the archive in a private directory and runs the callback. |
| `test-package-integration.sh: discover_artifact_version` | The distribution directory. | Prints the one version shared by all expected artifacts. |
| `test-codeql-action-pair.sh: cleanup` | No arguments. | Removes the temporary fixture directory. |
| `test-codeql-action-pair.sh: run_checker` | A workflow file. | Validates the fixture with `actionlint` and runs the workflow action policy check. |
| `test-codeql-action-pair.sh: wrap_fixture` | A steps file and an output path. | Writes a complete workflow around the step lines. |
| `test-codeql-action-pair.sh: expect_workflow_result` | A mode, a name, and a workflow file. | Validates the fixture with `actionlint` and requires the checker to match the mode. |
| `test-codeql-action-pair.sh: expect_steps` | A mode, a name, and step lines. | Writes the step lines to a fixture, wraps it in a workflow, and runs the mode check. |
| `test-codeql-action-pair.sh: expect_workflow` | A mode, a name, and workflow lines. | Writes a complete workflow fixture and runs the mode check. |
| `test-codeql-action-pair.sh: must_fail` | A name and a workflow file. | Requires the checker to fail on the fixture. |
| `test-package-integration.sh: artifact_path` | An artifact name. | Prints its path below the distribution directory. |
| `test-package-integration.sh: require_artifact` | An artifact path. | Requires the artifact file. |
| `test-package-integration.sh: verify_artifact_checksum` | An artifact. | Requires its checksum file and verifies the digest. |
| `test-package-integration.sh: run_deb_test` | A target and two artifacts. | Installs and tests one DEB and its matching generic archive. |
| `test-package-integration.sh: run_deb_test_with_tarball_mount` | An extracted archive and DEB state. | Runs DEB and archive checks in the selected container. |
| `test-package-integration.sh: run_rpm_test` | A target and two artifacts. | Installs and tests one RPM and the `amd64` generic archive. |
| `test-package-integration.sh: run_rpm_test_with_tarball_mount` | An extracted archive and RPM state. | Runs RPM and archive checks in the selected container. |
| `test-package-integration.sh: main` | Locked images and artifacts. | Verifies checksums, packages, archives, privilege behavior, and supported platforms. |
| `verify-release-reproducibility.sh: require_cmd` | A command name. | Requires the command on `PATH`. |
| `verify-release-reproducibility.sh: resolve_source_date_epoch` | An explicit time or Git state. | Prints a numeric source time. |
| `verify-release-reproducibility.sh: list_artifacts` | An artifact directory. | Prints a sorted file-name list. |
| `verify-release-reproducibility.sh: sha256_file` | A file. | Prints its SHA-256 digest with an available checksum command. |
| `verify-release-reproducibility.sh: compare_artifacts` | Two artifact directories. | Requires equal non-empty file sets and equal digests. |
| `verify-release-reproducibility.sh: cleanup` | A private reproduction directory. | Removes the registered directory after comparison. |

The scripts also call external commands and container images. [RUNTIMES.md](RUNTIMES.md) identifies the runtime sources.
