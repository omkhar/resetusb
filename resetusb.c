#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void) {
    libusb_context *ctx = NULL;
    libusb_device **devices = NULL;
    int failures = 0;
    int resets = 0;

    if (geteuid() != 0) {
        fprintf(stderr, "Must be root\n");
        return 1;
    }

    int rc = libusb_init(&ctx);
    if (rc != LIBUSB_SUCCESS) {
        fprintf(stderr, "Failed to initialize libusb: %s\n", libusb_error_name(rc));
        return 1;
    }

    ssize_t device_count = libusb_get_device_list(ctx, &devices);
    if (device_count < 0) {
        fprintf(stderr, "Failed to enumerate USB devices: %s\n", libusb_error_name((int)device_count));
        libusb_exit(ctx);
        return 1;
    }

    for (ssize_t i = 0; i < device_count; i++) {
        libusb_device *device = devices[i];
        libusb_device_handle *handle = NULL;
        struct libusb_device_descriptor descriptor;
        char product[256] = "<unknown>";

        rc = libusb_get_device_descriptor(device, &descriptor);
        if (rc != LIBUSB_SUCCESS) {
            fprintf(stderr,
                    "Failed to read descriptor for bus %u device %u: %s\n",
                    (unsigned int)libusb_get_bus_number(device),
                    (unsigned int)libusb_get_device_address(device),
                    libusb_error_name(rc));
            failures++;
            continue;
        }

        rc = libusb_open(device, &handle);
        if (rc != LIBUSB_SUCCESS) {
            fprintf(stderr,
                    "Can't open bus %u device %u (%04x:%04x): %s\n",
                    (unsigned int)libusb_get_bus_number(device),
                    (unsigned int)libusb_get_device_address(device),
                    (unsigned int)descriptor.idVendor,
                    (unsigned int)descriptor.idProduct,
                    libusb_error_name(rc));
            failures++;
            continue;
        }

        if (descriptor.iProduct != 0) {
            int len = libusb_get_string_descriptor_ascii(
                handle,
                descriptor.iProduct,
                (unsigned char *)product,
                sizeof(product) - 1);
            if (len > 0) {
                product[len] = '\0';
            } else {
                snprintf(product, sizeof(product), "<string unavailable>");
            }
        }

        rc = libusb_reset_device(handle);
        if (rc == LIBUSB_SUCCESS) {
            printf("reset bus %u device %u (%04x:%04x) %s\n",
                   (unsigned int)libusb_get_bus_number(device),
                   (unsigned int)libusb_get_device_address(device),
                   (unsigned int)descriptor.idVendor,
                   (unsigned int)descriptor.idProduct,
                   product);
            resets++;
        } else {
            fprintf(stderr,
                    "Failed reset bus %u device %u (%04x:%04x) %s: %s\n",
                    (unsigned int)libusb_get_bus_number(device),
                    (unsigned int)libusb_get_device_address(device),
                    (unsigned int)descriptor.idVendor,
                    (unsigned int)descriptor.idProduct,
                    product,
                    libusb_error_name(rc));
            failures++;
        }

        libusb_close(handle);
    }

    libusb_free_device_list(devices, 1);
    libusb_exit(ctx);

    printf("Summary: reset %d device(s), %d failure(s)\n", resets, failures);
    return failures == 0 ? 0 : 1;
}
