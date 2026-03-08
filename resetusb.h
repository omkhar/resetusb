#ifndef RESETUSB_H
#define RESETUSB_H

#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <sys/types.h>

typedef struct resetusb_ops {
	int (*libusb_init)(libusb_context **ctx);
	ssize_t (*libusb_get_device_list)(libusb_context *ctx,
					  libusb_device ***list);
	void (*libusb_free_device_list)(libusb_device **list,
					int unref_devices);
	void (*libusb_exit)(libusb_context *ctx);
	uint8_t (*libusb_get_bus_number)(libusb_device *dev);
	uint8_t (*libusb_get_device_address)(libusb_device *dev);
	int (*libusb_get_device_descriptor)(
		libusb_device *dev, struct libusb_device_descriptor *desc);
	int (*libusb_open)(libusb_device *dev, libusb_device_handle **handle);
	int (*libusb_get_string_descriptor_ascii)(libusb_device_handle *handle,
						  uint8_t desc_index,
						  unsigned char *data,
						  int length);
	int (*libusb_reset_device)(libusb_device_handle *handle);
	void (*libusb_close)(libusb_device_handle *handle);
	const char *(*libusb_error_name)(int code);
} resetusb_ops;

int resetusb_run(const resetusb_ops *ops, uid_t ruid, uid_t euid, FILE *out,
		 FILE *err);

#endif
