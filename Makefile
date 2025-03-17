default:
	gcc -Wall -Werror -Wpedantic -o resetusb resetusb.c -lusb

clean:
	rm resetusb

install:
	install -Dm700 resetusb /usr/sbin/resetusb

uninstall:
	rm /usr/sbin/resetusb
