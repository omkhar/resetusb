## Summary

<!-- What changed and why? -->

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
