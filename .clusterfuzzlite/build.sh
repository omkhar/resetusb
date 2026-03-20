#!/bin/bash -eu

$CC $CFLAGS -I"$SRC/resetusb" \
  -c "$SRC/resetusb/tests/resetusb_sanitize_fuzzer.c" \
  -o "$WORK/resetusb_sanitize_fuzzer.o"

$CXX $CXXFLAGS \
  "$WORK/resetusb_sanitize_fuzzer.o" \
  -o "$OUT/resetusb_sanitize_fuzzer" \
  $LIB_FUZZING_ENGINE
