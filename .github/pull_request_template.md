## Summary

<!-- What changed and why? -->

<!-- Keep the PR narrow enough for a human reviewer to reason about quickly.
     CI now rejects PRs over 20 changed files or 700 changed lines. Split
     unrelated or oversized work before pushing. -->

## Validation

<!-- Paste exact commands + summarized output -->

- [ ] `make clean && make && make test`
- [ ] `make lint`
- [ ] `make check-format`
- [ ] `scan-build --status-bugs --keep-empty --exclude /usr/include make clean all test`
- [ ] `make sanitize`

## Safety Checklist

- [ ] I confirmed no staging/production deploy jobs were added.
- [ ] I added/updated tests for behavior changes.
- [ ] I reviewed logs/output for sensitive data exposure.
- [ ] I kept GitHub Actions references pinned to immutable commit SHAs.
- [ ] I followed Linux kernel style in C source changes.
- [ ] I kept this PR reviewable in size and scope, or I split unrelated work out.
- [ ] I removed internal-only notes, local paths, usernames, scratch artifacts, and similar repo detritus.
