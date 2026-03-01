#include "resetusb.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>

static const char *safe_error_name(const resetusb_ops *ops, int code) {
    const char *name = NULL;
    if (ops->libusb_error_name != NULL) {
        name = ops->libusb_error_name(code);
    }
    return name != NULL ? name : "unknown";
}

int resetusb_run(const resetusb_ops *ops, uid_t euid, FILE *out, FILE *err) {
    libusb_context *ctx = NULL;
    libusb_device **devices = NULL;
    int failures = 0;
    int resets = 0;

    if (ops == NULL || out == NULL || err == NULL) {
        return 1;
    }

    if (euid != 0) {
        fprintf(err, "Must be root\n");
        return 1;
    }

    int rc = ops->libusb_init(&ctx);
    if (rc != LIBUSB_SUCCESS) {
        fprintf(err, "Failed to initialize libusb: %s\n", safe_error_name(ops, rc));
        return 1;
    }

    ssize_t device_count = ops->libusb_get_device_list(ctx, &devices);
    if (device_count < 0) {
        fprintf(err,
                "Failed to enumerate USB devices: %s\n",
                safe_error_name(ops, (int)device_count));
        ops->libusb_exit(ctx);
        return 1;
    }

    for (ssize_t i = 0; i < device_count; i++) {
        libusb_device *device = devices[i];
        libusb_device_handle *handle = NULL;
        struct libusb_device_descriptor descriptor;
        char product[256] = "<unknown>";

        rc = ops->libusb_get_device_descriptor(device, &descriptor);
        if (rc != LIBUSB_SUCCESS) {
            fprintf(err,
                    "Failed to read descriptor for bus %u device %u: %s\n",
                    (unsigned int)ops->libusb_get_bus_number(device),
                    (unsigned int)ops->libusb_get_device_address(device),
                    safe_error_name(ops, rc));
            failures++;
            continue;
        }

        rc = ops->libusb_open(device, &handle);
        if (rc != LIBUSB_SUCCESS) {
            fprintf(err,
                    "Can't open bus %u device %u (%04x:%04x): %s\n",
                    (unsigned int)ops->libusb_get_bus_number(device),
                    (unsigned int)ops->libusb_get_device_address(device),
                    (unsigned int)descriptor.idVendor,
                    (unsigned int)descriptor.idProduct,
                    safe_error_name(ops, rc));
            failures++;
            continue;
        }

        if (descriptor.iProduct != 0U) {
            int len = ops->libusb_get_string_descriptor_ascii(
                handle,
                descriptor.iProduct,
                (unsigned char *)product,
                (int)sizeof(product) - 1);
            if (len > 0) {
                product[len] = '\0';
            } else {
                snprintf(product, sizeof(product), "<string unavailable>");
            }
        }

        rc = ops->libusb_reset_device(handle);
        if (rc == LIBUSB_SUCCESS) {
            fprintf(out,
                    "reset bus %u device %u (%04x:%04x) %s\n",
                    (unsigned int)ops->libusb_get_bus_number(device),
                    (unsigned int)ops->libusb_get_device_address(device),
                    (unsigned int)descriptor.idVendor,
                    (unsigned int)descriptor.idProduct,
                    product);
            resets++;
        } else {
            fprintf(err,
                    "Failed reset bus %u device %u (%04x:%04x) %s: %s\n",
                    (unsigned int)ops->libusb_get_bus_number(device),
                    (unsigned int)ops->libusb_get_device_address(device),
                    (unsigned int)descriptor.idVendor,
                    (unsigned int)descriptor.idProduct,
                    product,
                    safe_error_name(ops, rc));
            failures++;
        }

        ops->libusb_close(handle);
    }

    ops->libusb_free_device_list(devices, 1);
    ops->libusb_exit(ctx);

    fprintf(out, "Summary: reset %d device(s), %d failure(s)\n", resets, failures);
    return failures == 0 ? 0 : 1;
}

#ifndef RESETUSB_TEST
static const resetusb_ops default_ops = {
    .libusb_init = libusb_init,
    .libusb_get_device_list = libusb_get_device_list,
    .libusb_free_device_list = libusb_free_device_list,
    .libusb_exit = libusb_exit,
    .libusb_get_bus_number = libusb_get_bus_number,
    .libusb_get_device_address = libusb_get_device_address,
    .libusb_get_device_descriptor = libusb_get_device_descriptor,
    .libusb_open = libusb_open,
    .libusb_get_string_descriptor_ascii = libusb_get_string_descriptor_ascii,
    .libusb_reset_device = libusb_reset_device,
    .libusb_close = libusb_close,
    .libusb_error_name = libusb_error_name,
};

int main(void) { return resetusb_run(&default_ops, geteuid(), stdout, stderr); }
#endif
