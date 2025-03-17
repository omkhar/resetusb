/* Mostly taken from https://stackoverflow.com/questions/18195237/c-how-can-i-reset-the-usb-bus-under-linux 
 * Walks the entire USB bus and attempts to reset it. Useful for waking up buggy USB devices
*/
#include <stdio.h>
#include <usb.h>
#include <unistd.h>

int main(void) {
	struct usb_bus *busses;
	usb_init();
	usb_find_busses();
	usb_find_devices();
	busses = usb_get_busses();
	struct usb_bus *bus;
	if (geteuid() != 0) {
		fprintf(stderr,"Must be root\n");
		exit(1);
	}
	for (bus = busses; bus; bus = bus->next) {
		struct usb_device *dev;
		int val;
		usb_dev_handle *handle;
		for (dev = bus->devices; dev; dev = dev->next) {
			char buf[1024];
			handle = usb_open ( dev );
			usb_get_string_simple(handle,2,buf,1023);
			if ( handle == NULL ){
				fprintf(stderr,"Can't open %p (%s)\n", (void *)dev, buf );
			} else {
				val = usb_reset(handle);
				fprintf(stdout, "reset %p %d (%s)\n", (void *)dev, val, buf );
			}
			usb_close(handle);
		}
	}
}
