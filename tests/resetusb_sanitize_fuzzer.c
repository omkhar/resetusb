#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define RESETUSB_TEST
#include "../resetusb.c"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	char *name = NULL;

	if (size == SIZE_MAX) {
		return 0;
	}

	name = malloc(size + 1);
	if (name == NULL) {
		return 0;
	}

	if (size > 0U) {
		memcpy(name, data, size);
	}
	name[size] = '\0';

	sanitize_product_name(name);
	free(name);
	return 0;
}
