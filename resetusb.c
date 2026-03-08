#include "resetusb.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int ops_complete(const resetusb_ops *ops)
{
	return ops != NULL && ops->libusb_init != NULL &&
	       ops->libusb_get_device_list != NULL &&
	       ops->libusb_free_device_list != NULL &&
	       ops->libusb_exit != NULL && ops->libusb_get_bus_number != NULL &&
	       ops->libusb_get_device_address != NULL &&
	       ops->libusb_get_device_descriptor != NULL &&
	       ops->libusb_open != NULL &&
	       ops->libusb_get_string_descriptor_ascii != NULL &&
	       ops->libusb_reset_device != NULL && ops->libusb_close != NULL &&
	       ops->libusb_error_name != NULL;
}

static const char *safe_error_name(const resetusb_ops *ops, int code)
{
	const char *name = NULL;
	if (ops->libusb_error_name != NULL) {
		name = ops->libusb_error_name(code);
	}
	return name != NULL ? name : "unknown";
}

static void sanitize_product_name(char *name)
{
	if (name == NULL) {
		return;
	}

	for (size_t i = 0; name[i] != '\0'; i++) {
		unsigned char ch = (unsigned char)name[i];
		if (!isprint(ch)) {
			name[i] = '?';
		}
	}
}

int resetusb_run(const resetusb_ops *ops, uid_t ruid, uid_t euid, FILE *out,
		 FILE *err)
{
	libusb_context *ctx = NULL;
	libusb_device **devices = NULL;
	int failures = 0;
	int resets = 0;

	if (out == NULL || err == NULL) {
		return 1;
	}

	if (!ops_complete(ops)) {
		fprintf(err,
			"Internal error: incomplete libusb operations table\n");
		return 1;
	}

	if (ruid != euid) {
		fprintf(err, "Refusing to run with mismatched real and "
			     "effective UIDs\n");
		return 1;
	}

	if (ruid != 0 || euid != 0) {
		fprintf(err, "Must be root\n");
		return 1;
	}

	int rc = ops->libusb_init(&ctx);
	if (rc != LIBUSB_SUCCESS) {
		fprintf(err, "Failed to initialize libusb: %s\n",
			safe_error_name(ops, rc));
		return 1;
	}

	ssize_t device_count = ops->libusb_get_device_list(ctx, &devices);
	if (device_count < 0) {
		fprintf(err, "Failed to enumerate USB devices: %s\n",
			safe_error_name(ops, (int)device_count));
		ops->libusb_exit(ctx);
		return 1;
	}

	if (device_count > 0 && devices == NULL) {
		fprintf(err,
			"Failed to enumerate USB devices: null device list\n");
		ops->libusb_exit(ctx);
		return 1;
	}

	for (ssize_t i = 0; i < device_count; i++) {
		libusb_device *device = devices[i];
		libusb_device_handle *handle = NULL;
		struct libusb_device_descriptor descriptor;
		char product[256] = "<unknown>";

		if (device == NULL) {
			fprintf(err,
				"Encountered null device entry at index %zd\n",
				i);
			failures++;
			continue;
		}

		rc = ops->libusb_get_device_descriptor(device, &descriptor);
		if (rc != LIBUSB_SUCCESS) {
			fprintf(err,
				"Failed to read descriptor for bus %u device "
				"%u: %s\n",
				(unsigned int)ops->libusb_get_bus_number(
					device),
				(unsigned int)ops->libusb_get_device_address(
					device),
				safe_error_name(ops, rc));
			failures++;
			continue;
		}

		rc = ops->libusb_open(device, &handle);
		if (rc != LIBUSB_SUCCESS) {
			fprintf(err,
				"Can't open bus %u device %u (%04x:%04x): %s\n",
				(unsigned int)ops->libusb_get_bus_number(
					device),
				(unsigned int)ops->libusb_get_device_address(
					device),
				(unsigned int)descriptor.idVendor,
				(unsigned int)descriptor.idProduct,
				safe_error_name(ops, rc));
			failures++;
			continue;
		}

		if (descriptor.iProduct != 0U) {
			int len = ops->libusb_get_string_descriptor_ascii(
				handle, descriptor.iProduct,
				(unsigned char *)product,
				(int)sizeof(product) - 1);
			if (len > 0) {
				size_t product_len = (size_t)len;
				if (product_len >= sizeof(product)) {
					product_len = sizeof(product) - 1;
				}
				product[product_len] = '\0';
				sanitize_product_name(product);
			} else {
				snprintf(product, sizeof(product),
					 "<string unavailable>");
			}
		}

		rc = ops->libusb_reset_device(handle);
		if (rc == LIBUSB_SUCCESS) {
			fprintf(out, "reset bus %u device %u (%04x:%04x) %s\n",
				(unsigned int)ops->libusb_get_bus_number(
					device),
				(unsigned int)ops->libusb_get_device_address(
					device),
				(unsigned int)descriptor.idVendor,
				(unsigned int)descriptor.idProduct, product);
			resets++;
		} else {
			fprintf(err,
				"Failed reset bus %u device %u (%04x:%04x) %s: "
				"%s\n",
				(unsigned int)ops->libusb_get_bus_number(
					device),
				(unsigned int)ops->libusb_get_device_address(
					device),
				(unsigned int)descriptor.idVendor,
				(unsigned int)descriptor.idProduct, product,
				safe_error_name(ops, rc));
			failures++;
		}

		ops->libusb_close(handle);
	}

	ops->libusb_free_device_list(devices, 1);
	ops->libusb_exit(ctx);

	fprintf(out, "Summary: reset %d device(s), %d failure(s)\n", resets,
		failures);
	return failures == 0 ? 0 : 1;
}

#ifndef RESETUSB_TEST
int main(void);

static const resetusb_ops default_ops = {
	.libusb_init = libusb_init,
	.libusb_get_device_list = libusb_get_device_list,
	.libusb_free_device_list = libusb_free_device_list,
	.libusb_exit = libusb_exit,
	.libusb_get_bus_number = libusb_get_bus_number,
	.libusb_get_device_address = libusb_get_device_address,
	.libusb_get_device_descriptor = libusb_get_device_descriptor,
	.libusb_open = libusb_open,
	.libusb_get_string_descriptor_ascii =
		libusb_get_string_descriptor_ascii,
	.libusb_reset_device = libusb_reset_device,
	.libusb_close = libusb_close,
	.libusb_error_name = libusb_error_name,
};

int main(void)
{
	return resetusb_run(&default_ops, getuid(), geteuid(), stdout, stderr);
}
#endif
