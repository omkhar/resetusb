CC ?= cc
CFLAGS ?= -Wall -Werror -Wpedantic -O2
HARDEN_CFLAGS ?= -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIE
HARDEN_LDFLAGS ?= -Wl,-z,relro,-z,now -pie
LDLIBS += -lusb-1.0
UNIT_TEST_BIN := resetusb-tests
UNIT_TEST_SRC := tests/resetusb_unit_tests.c

PREFIX ?= /usr
SBINDIR ?= $(PREFIX)/sbin
UNAME_S := $(shell uname -s)

.PHONY: all clean install uninstall test

ifeq ($(UNAME_S),Linux)
EFFECTIVE_CFLAGS := $(CFLAGS) $(HARDEN_CFLAGS)
EFFECTIVE_LDFLAGS := $(LDFLAGS) $(HARDEN_LDFLAGS)

all: resetusb

resetusb: resetusb.c
	$(CC) $(CPPFLAGS) $(EFFECTIVE_CFLAGS) -o $@ $< $(EFFECTIVE_LDFLAGS) $(LDLIBS)

$(UNIT_TEST_BIN): $(UNIT_TEST_SRC) resetusb.c resetusb.h
	$(CC) $(CPPFLAGS) $(EFFECTIVE_CFLAGS) -DRESETUSB_TEST -o $@ $(UNIT_TEST_SRC) resetusb.c $(EFFECTIVE_LDFLAGS)

test: resetusb $(UNIT_TEST_BIN)
	./$(UNIT_TEST_BIN)

install: resetusb
	install -Dm700 resetusb $(SBINDIR)/resetusb
else
all resetusb install:
	@echo "resetusb only builds on Linux (detected: $(UNAME_S))" >&2
	@false

test:
	@echo "resetusb tests are Linux-only (detected: $(UNAME_S)); skipping"
endif

clean:
	rm -f resetusb $(UNIT_TEST_BIN)

uninstall:
	rm -f $(SBINDIR)/resetusb
