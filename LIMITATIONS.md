# resetusb limitations

This document uses ASD-STE100 Simplified Technical English.

## Command scope

- `resetusb` operates only on Linux.
- `resetusb` requires real and effective user ID 0.
- `resetusb` rejects a process when its real and effective user IDs are different.
- `resetusb` ignores all command-line arguments. Thus, `--help` does not show help.
- `resetusb` has no device filter and no exclusion list.
- `resetusb` attempts a reset only after it reads a device descriptor and opens a non-null handle.
- The device list can include hubs, keyboards, storage, serial adapters, and network adapters.
- `resetusb` does not provide a dry-run mode.
- `resetusb` does not ask for confirmation.

## Reset behavior

- `resetusb` processes devices one at a time. It does not reset devices concurrently.
- `resetusb` uses the `libusb` enumeration order. It does not sort devices.
- `resetusb` does not guarantee a stable device order.
- `resetusb` does not retry a reset.
- `resetusb` does not roll back a reset.
- `libusb` can require re-enumeration after a reset.
- `resetusb` records this condition as a failure. It does not rediscover the device.
- `resetusb` has no reset timeout or cancellation control.
- `resetusb` does not explicitly detach or attach kernel drivers.
- `resetusb` does not quiesce drivers or file systems.
- `resetusb` does not unmount storage or stop network services.
- `resetusb` does not guarantee that a device will recover.
- A reset can disconnect the USB devices that you use to control the host.
- Make sure that you have a different recovery path.

## Errors and output

- A failure to initialize `libusb` or enumerate devices stops the operation.
- A positive count with a null device list also stops the operation.
- No summary follows these failures.
- A null device entry, descriptor failure, open failure, null handle, or reset failure counts as one failure.
- The program continues with the next device after a device-specific failure.
- The program closes each non-null handle after the reset attempt.
- The product name is `<unknown>` when a descriptor has no product-string index.
- The product name is `<string unavailable>` when `libusb` cannot return a product string.
- The program changes each non-printable product-name byte to `?` before it writes output.
- The program limits a product name to 255 bytes plus a null terminator.
- The program writes successful reset lines and the final summary to standard output.
- The program writes errors to standard error.
- Exit status 0 requires successful initialization, enumeration, and all device-specific operations.
- A descriptor, open, null-handle, or reset failure causes exit status 1.

## Interfaces

- `resetusb_run` and `resetusb_ops` are an internal test seam.
- They are not a stable library interface.
- `resetusb_run` returns 1 without output when an output stream pointer is null.
- `resetusb_run` returns 1 when the operations table is null or incomplete.
- With two non-null streams, an incomplete operations table writes an internal error.
- The install target installs the executable and the manual page. It does not install `resetusb.h`.
- Generic archives need the system `libusb-1.0` shared library.

See [RUNTIMES.md](RUNTIMES.md) for runtime requirements. See [FUNCTIONS.md](FUNCTIONS.md) for the function inventory.
