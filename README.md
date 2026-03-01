# resetusb

Small utility program for Linux that enumerates and resets all USB devices (including hubs).

## Requirements

- libusb-1.0 development headers (`libusb-1.0-0-dev` on Debian/Ubuntu)
- A C compiler and `make`

## Build

```sh
make
```

## Run

`resetusb` requires root privileges and will attempt to reset every enumerated USB device:

```sh
sudo ./resetusb
```

This can temporarily disrupt active USB peripherals and USB-backed networking devices.
