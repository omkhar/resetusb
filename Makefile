CC ?= cc
CFLAGS ?= -Wall -Werror -Wpedantic -O2
LDLIBS += -lusb-1.0

PREFIX ?= /usr
SBINDIR ?= $(PREFIX)/sbin
UNAME_S := $(shell uname -s)

.PHONY: all clean install uninstall

ifeq ($(UNAME_S),Linux)
all: resetusb

resetusb: resetusb.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LDLIBS)

install: resetusb
	install -Dm700 resetusb $(SBINDIR)/resetusb
else
all resetusb install:
	@echo "resetusb only builds on Linux (detected: $(UNAME_S))" >&2
	@false
endif

clean:
	rm -f resetusb

uninstall:
	rm -f $(SBINDIR)/resetusb
