## Summary

<!-- What changed and why? -->

## Validation

<!-- Paste exact commands + summarized output -->

- [ ] `make clean && make && make test`
- [ ] `cppcheck --enable=warning,style,performance,portability --error-exitcode=1 --suppress=missingIncludeSystem resetusb.c`
- [ ] `shellcheck scripts/*.sh`
- [ ] `scan-build --status-bugs --keep-empty --exclude /usr/include make clean all test`

## Safety Checklist

- [ ] I confirmed no staging/production deploy jobs were added.
- [ ] I added/updated tests for behavior changes.
- [ ] I reviewed logs/output for sensitive data exposure.
- [ ] I kept GitHub Actions references pinned to immutable commit SHAs.
