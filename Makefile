default:
	gcc -Os -march=native -mtune=native -o resetusb resetusb.c -lusb

clean:
	rm resetusb
