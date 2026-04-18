CC ?= cc
CLANG_FORMAT ?= clang-format
COMMON_CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Wformat -Wformat=2 -Wconversion \
	-Wimplicit-fallthrough -Wmissing-prototypes -Wstrict-prototypes \
	-Wshadow -Wvla -Werror -Werror=format-security \
	-Wpedantic
CFLAGS ?= $(COMMON_CFLAGS)
HARDEN_CFLAGS ?= -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -fstrict-flex-arrays=3 \
	-fstack-clash-protection -fstack-protector-strong -fPIE
HARDEN_LDFLAGS ?= -Wl,-z,nodlopen -Wl,-z,noexecstack -Wl,-z,relro,-z,now -pie \
	-Wl,--as-needed -Wl,--no-copy-dt-needed-entries
CPPFLAGS += -D_POSIX_C_SOURCE=200809L
LDLIBS += -lusb-1.0
CC_BIN := $(notdir $(lastword $(CC)))
EXTRA_WARN_CFLAGS :=

ifeq ($(CC_BIN),gcc)
EXTRA_WARN_CFLAGS += -Wtrampolines
endif

ifeq ($(CC_BIN),cc)
EXTRA_WARN_CFLAGS += -Wtrampolines
endif

UNIT_TEST_BIN := resetusb-tests
UNIT_TEST_SRC := tests/resetusb_unit_tests.c
FUZZ_BIN := resetusb-fuzzer
FUZZ_SRC := tests/resetusb_sanitize_fuzzer.c
FUZZ_CC ?= clang
FUZZ_TIME ?= 10
FORMAT_SRCS := resetusb.c resetusb.h tests/resetusb_unit_tests.c \
	tests/resetusb_sanitize_fuzzer.c

PREFIX ?= /usr
SBINDIR ?= $(PREFIX)/sbin
MANDIR ?= $(PREFIX)/share/man
MAN8DIR ?= $(MANDIR)/man8
UNAME_S := $(shell uname -s)

.PHONY: all clean install uninstall test lint format check-format sanitize \
	fuzz release-preflight check-release-contract

ifeq ($(UNAME_S),Linux)
EFFECTIVE_CFLAGS := $(CFLAGS) $(EXTRA_WARN_CFLAGS) $(HARDEN_CFLAGS)
EFFECTIVE_LDFLAGS := $(LDFLAGS) $(HARDEN_LDFLAGS)

all: resetusb

resetusb: resetusb.c resetusb.h
	$(CC) $(CPPFLAGS) $(EFFECTIVE_CFLAGS) -o $@ resetusb.c \
		$(EFFECTIVE_LDFLAGS) $(LDLIBS)

$(UNIT_TEST_BIN): $(UNIT_TEST_SRC) resetusb.c resetusb.h
	$(CC) $(CPPFLAGS) $(EFFECTIVE_CFLAGS) -DRESETUSB_TEST -o $@ \
		$(UNIT_TEST_SRC) resetusb.c $(EFFECTIVE_LDFLAGS)

$(FUZZ_BIN): $(FUZZ_SRC) resetusb.c resetusb.h
	@command -v "$(FUZZ_CC)" >/dev/null 2>&1 || \
		{ echo "$(FUZZ_CC) not found" >&2; exit 1; }
	$(FUZZ_CC) $(CPPFLAGS) $(CFLAGS) -O1 -g3 -fno-omit-frame-pointer \
		-fsanitize=fuzzer,address,undefined -o $@ $(FUZZ_SRC)

test: resetusb $(UNIT_TEST_BIN)
	./$(UNIT_TEST_BIN)

sanitize: clean
	$(MAKE) CC="$(CC)" \
		CFLAGS="$(CFLAGS) -O1 -g3 -fno-omit-frame-pointer -fsanitize=address,undefined" \
		LDFLAGS="$(LDFLAGS) -fsanitize=address,undefined" \
		HARDEN_CFLAGS="" \
		HARDEN_LDFLAGS="" \
		test

fuzz: $(FUZZ_BIN)
	./$(FUZZ_BIN) -max_total_time="$(FUZZ_TIME)"

install: resetusb
	install -Dm700 resetusb $(SBINDIR)/resetusb
	install -Dm644 resetusb.8 $(MAN8DIR)/resetusb.8
else
all resetusb install sanitize:
	@echo "resetusb only builds on Linux (detected: $(UNAME_S))" >&2
	@false

test:
	@echo "resetusb tests are Linux-only (detected: $(UNAME_S)); skipping"

fuzz:
	@echo "resetusb fuzzing is Linux-only (detected: $(UNAME_S)); skipping"
endif

format:
	@command -v "$(CLANG_FORMAT)" >/dev/null 2>&1 || \
		{ echo "$(CLANG_FORMAT) not found" >&2; exit 1; }
	$(CLANG_FORMAT) -i $(FORMAT_SRCS)

check-format:
	@command -v "$(CLANG_FORMAT)" >/dev/null 2>&1 || \
		{ echo "$(CLANG_FORMAT) not found" >&2; exit 1; }
	$(CLANG_FORMAT) --dry-run --Werror $(FORMAT_SRCS)

lint:
	@command -v cppcheck >/dev/null 2>&1 || \
		{ echo "cppcheck not found" >&2; exit 1; }
	cppcheck --enable=warning,style,performance,portability \
		--check-level=exhaustive \
		--error-exitcode=1 --suppress=missingIncludeSystem \
		--suppress=constParameterCallback:tests/resetusb_unit_tests.c \
		resetusb.c tests/resetusb_unit_tests.c
	@if [ -d scripts ] && find scripts -maxdepth 1 -type f -name '*.sh' | grep -q .; then \
		command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found" >&2; exit 1; }; \
		shellcheck scripts/*.sh; \
	else \
		echo "No shell scripts to lint."; \
	fi
	./scripts/check-release-security-contract.sh

check-release-contract:
	./scripts/check-release-security-contract.sh

clean:
	rm -f resetusb $(UNIT_TEST_BIN) $(FUZZ_BIN)

uninstall:
	rm -f $(SBINDIR)/resetusb
	rm -f $(MAN8DIR)/resetusb.8

release-preflight:
	./scripts/release-preflight.sh
