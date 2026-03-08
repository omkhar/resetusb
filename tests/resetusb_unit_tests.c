#include "../resetusb.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct fake_state {
	int init_rc;
	ssize_t device_count;
	int init_calls;
	int get_device_list_calls;
	int free_device_list_calls;
	int exit_calls;

	libusb_device *devices[3];
	libusb_device_handle *handles[2];
	uint8_t bus_numbers[2];
	uint8_t device_addresses[2];

	int descriptor_rc[2];
	struct libusb_device_descriptor descriptors[2];
	int descriptor_calls[2];

	int open_rc[2];
	int open_calls[2];

	int string_rc[2];
	const char *string_value[2];
	int string_calls[2];

	int reset_rc[2];
	int reset_calls[2];

	int close_calls[2];
} fake_state;

static fake_state g_fake;

static int token_device_0;
static int token_device_1;
static int token_handle_0;
static int token_handle_1;

static int index_for_device(const libusb_device *device)
{
	if (device == g_fake.devices[0]) {
		return 0;
	}
	if (device == g_fake.devices[1]) {
		return 1;
	}
	return -1;
}

static int index_for_handle(const libusb_device_handle *handle)
{
	if (handle == g_fake.handles[0]) {
		return 0;
	}
	if (handle == g_fake.handles[1]) {
		return 1;
	}
	return -1;
}

static int fake_libusb_init(libusb_context **ctx)
{
	g_fake.init_calls++;
	if (ctx != NULL) {
		*ctx = (libusb_context *)&g_fake;
	}
	return g_fake.init_rc;
}

static ssize_t fake_libusb_get_device_list(libusb_context *ctx,
					   libusb_device ***list)
{
	(void)ctx;
	g_fake.get_device_list_calls++;
	if (list != NULL) {
		*list = g_fake.devices;
	}
	return g_fake.device_count;
}

static void fake_libusb_free_device_list(libusb_device **list,
					 int unref_devices)
{
	(void)list;
	(void)unref_devices;
	g_fake.free_device_list_calls++;
}

static void fake_libusb_exit(libusb_context *ctx)
{
	(void)ctx;
	g_fake.exit_calls++;
}

static uint8_t fake_libusb_get_bus_number(libusb_device *device)
{
	int idx = index_for_device(device);
	return idx >= 0 ? g_fake.bus_numbers[idx] : 0;
}

static uint8_t fake_libusb_get_device_address(libusb_device *device)
{
	int idx = index_for_device(device);
	return idx >= 0 ? g_fake.device_addresses[idx] : 0;
}

static int
fake_libusb_get_device_descriptor(libusb_device *device,
				  struct libusb_device_descriptor *desc)
{
	int idx = index_for_device(device);
	if (idx < 0) {
		return LIBUSB_ERROR_OTHER;
	}

	g_fake.descriptor_calls[idx]++;
	if (g_fake.descriptor_rc[idx] == LIBUSB_SUCCESS && desc != NULL) {
		*desc = g_fake.descriptors[idx];
	}
	return g_fake.descriptor_rc[idx];
}

static int fake_libusb_open(libusb_device *device,
			    libusb_device_handle **handle)
{
	int idx = index_for_device(device);
	if (idx < 0) {
		return LIBUSB_ERROR_OTHER;
	}

	g_fake.open_calls[idx]++;
	if (g_fake.open_rc[idx] == LIBUSB_SUCCESS && handle != NULL) {
		*handle = g_fake.handles[idx];
	}
	return g_fake.open_rc[idx];
}

static int fake_libusb_get_string_descriptor_ascii(libusb_device_handle *handle,
						   uint8_t desc_index,
						   unsigned char *data,
						   int length)
{
	(void)desc_index;
	int idx = index_for_handle(handle);
	if (idx < 0) {
		return LIBUSB_ERROR_OTHER;
	}
	g_fake.string_calls[idx]++;

	if (g_fake.string_rc[idx] > 0 && data != NULL && length > 0) {
		const char *value = g_fake.string_value[idx] == NULL
					    ? ""
					    : g_fake.string_value[idx];
		size_t want = strlen(value);
		size_t to_copy = want < (size_t)length ? want : (size_t)length;
		memcpy(data, value, to_copy);
	}

	return g_fake.string_rc[idx];
}

static int fake_libusb_reset_device(libusb_device_handle *handle)
{
	int idx = index_for_handle(handle);
	if (idx < 0) {
		return LIBUSB_ERROR_OTHER;
	}
	g_fake.reset_calls[idx]++;
	return g_fake.reset_rc[idx];
}

static void fake_libusb_close(libusb_device_handle *handle)
{
	int idx = index_for_handle(handle);
	if (idx >= 0) {
		g_fake.close_calls[idx]++;
	}
}

static const char *fake_libusb_error_name(int code)
{
	switch (code) {
	case LIBUSB_SUCCESS:
		return "LIBUSB_SUCCESS";
	case LIBUSB_ERROR_ACCESS:
		return "LIBUSB_ERROR_ACCESS";
	case LIBUSB_ERROR_IO:
		return "LIBUSB_ERROR_IO";
	case LIBUSB_ERROR_NOT_FOUND:
		return "LIBUSB_ERROR_NOT_FOUND";
	default:
		return "LIBUSB_ERROR_OTHER";
	}
}

static const resetusb_ops fake_ops = {
	.libusb_init = fake_libusb_init,
	.libusb_get_device_list = fake_libusb_get_device_list,
	.libusb_free_device_list = fake_libusb_free_device_list,
	.libusb_exit = fake_libusb_exit,
	.libusb_get_bus_number = fake_libusb_get_bus_number,
	.libusb_get_device_address = fake_libusb_get_device_address,
	.libusb_get_device_descriptor = fake_libusb_get_device_descriptor,
	.libusb_open = fake_libusb_open,
	.libusb_get_string_descriptor_ascii =
		fake_libusb_get_string_descriptor_ascii,
	.libusb_reset_device = fake_libusb_reset_device,
	.libusb_close = fake_libusb_close,
	.libusb_error_name = fake_libusb_error_name,
};

static void reset_fake(void)
{
	memset(&g_fake, 0, sizeof(g_fake));

	g_fake.init_rc = LIBUSB_SUCCESS;
	g_fake.device_count = 1;
	g_fake.devices[0] = (libusb_device *)&token_device_0;
	g_fake.devices[1] = NULL;
	g_fake.handles[0] = (libusb_device_handle *)&token_handle_0;
	g_fake.handles[1] = (libusb_device_handle *)&token_handle_1;

	g_fake.bus_numbers[0] = 1;
	g_fake.device_addresses[0] = 2;
	g_fake.bus_numbers[1] = 3;
	g_fake.device_addresses[1] = 4;

	g_fake.descriptor_rc[0] = LIBUSB_SUCCESS;
	g_fake.descriptor_rc[1] = LIBUSB_SUCCESS;
	g_fake.descriptors[0].idVendor = 0x1234;
	g_fake.descriptors[0].idProduct = 0x5678;
	g_fake.descriptors[0].iProduct = 1;
	g_fake.descriptors[1].idVendor = 0xabcd;
	g_fake.descriptors[1].idProduct = 0xef00;
	g_fake.descriptors[1].iProduct = 1;

	g_fake.open_rc[0] = LIBUSB_SUCCESS;
	g_fake.open_rc[1] = LIBUSB_SUCCESS;
	g_fake.string_rc[0] = 8;
	g_fake.string_rc[1] = 8;
	g_fake.string_value[0] = "Keyboard";
	g_fake.string_value[1] = "Mouse";
	g_fake.reset_rc[0] = LIBUSB_SUCCESS;
	g_fake.reset_rc[1] = LIBUSB_SUCCESS;
}

static char *read_stream(FILE *stream)
{
	if (fflush(stream) != 0) {
		return NULL;
	}
	if (fseek(stream, 0, SEEK_SET) != 0) {
		return NULL;
	}

	size_t cap = 256;
	size_t len = 0;
	char *buf = malloc(cap);
	if (buf == NULL) {
		return NULL;
	}

	int ch;
	while ((ch = fgetc(stream)) != EOF) {
		if (len + 1 >= cap) {
			cap *= 2;
			char *next = realloc(buf, cap);
			if (next == NULL) {
				free(buf);
				return NULL;
			}
			buf = next;
		}
		buf[len++] = (char)ch;
	}
	buf[len] = '\0';
	return buf;
}

static int run_with_capture(const resetusb_ops *ops, uid_t ruid, uid_t euid,
			    char **stdout_text, char **stderr_text)
{
	FILE *out = tmpfile();
	FILE *err = tmpfile();
	int rc;

	assert(out != NULL);
	assert(err != NULL);

	rc = resetusb_run(ops, ruid, euid, out, err);
	*stdout_text = read_stream(out);
	*stderr_text = read_stream(err);

	fclose(out);
	fclose(err);
	return rc;
}

static void test_requires_root(void)
{
	reset_fake();

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 1000, 1000, &out, &err);

	assert(rc == 1);
	assert(g_fake.init_calls == 0);
	assert(out != NULL && strcmp(out, "") == 0);
	assert(err != NULL && strstr(err, "Must be root") != NULL);

	free(out);
	free(err);
}

static void test_init_failure(void)
{
	reset_fake();
	g_fake.init_rc = LIBUSB_ERROR_ACCESS;

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 0, 0, &out, &err);

	assert(rc == 1);
	assert(g_fake.init_calls == 1);
	assert(g_fake.get_device_list_calls == 0);
	assert(out != NULL && strcmp(out, "") == 0);
	assert(err != NULL &&
	       strstr(err,
		      "Failed to initialize libusb: LIBUSB_ERROR_ACCESS") !=
		       NULL);

	free(out);
	free(err);
}

static void test_successful_reset(void)
{
	reset_fake();

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 0, 0, &out, &err);

	assert(rc == 0);
	assert(g_fake.init_calls == 1);
	assert(g_fake.get_device_list_calls == 1);
	assert(g_fake.free_device_list_calls == 1);
	assert(g_fake.exit_calls == 1);
	assert(g_fake.close_calls[0] == 1);
	assert(err != NULL && strcmp(err, "") == 0);
	assert(out != NULL &&
	       strstr(out, "reset bus 1 device 2 (1234:5678) Keyboard") !=
		       NULL);
	assert(out != NULL &&
	       strstr(out, "Summary: reset 1 device(s), 0 failure(s)") != NULL);

	free(out);
	free(err);
}

static void test_mixed_failures_counted(void)
{
	reset_fake();
	g_fake.device_count = 2;
	g_fake.devices[1] = (libusb_device *)&token_device_1;
	g_fake.descriptor_rc[0] = LIBUSB_ERROR_IO;
	g_fake.open_rc[1] = LIBUSB_ERROR_NOT_FOUND;

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 0, 0, &out, &err);

	assert(rc == 1);
	assert(g_fake.close_calls[0] == 0);
	assert(g_fake.close_calls[1] == 0);
	assert(out != NULL &&
	       strstr(out, "Summary: reset 0 device(s), 2 failure(s)") != NULL);
	assert(err != NULL && strstr(err, "Failed to read descriptor for bus 1 "
					  "device 2: LIBUSB_ERROR_IO") != NULL);
	assert(err != NULL &&
	       strstr(err, "Can't open bus 3 device 4 (abcd:ef00): "
			   "LIBUSB_ERROR_NOT_FOUND") != NULL);

	free(out);
	free(err);
}

static void test_reset_failure_closes_handle(void)
{
	reset_fake();
	g_fake.reset_rc[0] = LIBUSB_ERROR_IO;
	g_fake.string_rc[0] = -1;

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 0, 0, &out, &err);

	assert(rc == 1);
	assert(g_fake.close_calls[0] == 1);
	assert(out != NULL &&
	       strstr(out, "Summary: reset 0 device(s), 1 failure(s)") != NULL);
	assert(err != NULL &&
	       strstr(err, "Failed reset bus 1 device 2 (1234:5678) <string "
			   "unavailable>: LIBUSB_ERROR_IO") != NULL);

	free(out);
	free(err);
}

static void test_incomplete_ops_table_rejected(void)
{
	reset_fake();

	resetusb_ops bad_ops = fake_ops;
	bad_ops.libusb_reset_device = NULL;

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&bad_ops, 0, 0, &out, &err);

	assert(rc == 1);
	assert(g_fake.init_calls == 0);
	assert(out != NULL && strcmp(out, "") == 0);
	assert(err != NULL &&
	       strstr(err,
		      "Internal error: incomplete libusb operations table") !=
		       NULL);

	free(out);
	free(err);
}

static void test_product_name_sanitized(void)
{
	reset_fake();
	g_fake.string_value[0] = "Kbd\x1b[31m\n";
	g_fake.string_rc[0] = 9;

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 0, 0, &out, &err);

	assert(rc == 0);
	assert(err != NULL && strcmp(err, "") == 0);
	assert(out != NULL &&
	       strstr(out, "reset bus 1 device 2 (1234:5678) Kbd?[31m?") !=
		       NULL);
	assert(out != NULL &&
	       strstr(out, "Summary: reset 1 device(s), 0 failure(s)") != NULL);

	free(out);
	free(err);
}

static void test_null_device_entry_counted(void)
{
	reset_fake();
	g_fake.device_count = 2;
	g_fake.devices[1] = NULL;

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 0, 0, &out, &err);

	assert(rc == 1);
	assert(g_fake.close_calls[0] == 1);
	assert(out != NULL &&
	       strstr(out, "Summary: reset 1 device(s), 1 failure(s)") != NULL);
	assert(err != NULL &&
	       strstr(err, "Encountered null device entry at index 1") != NULL);

	free(out);
	free(err);
}

static void test_mismatched_uids_rejected(void)
{
	reset_fake();

	char *out = NULL;
	char *err = NULL;
	int rc = run_with_capture(&fake_ops, 1000, 0, &out, &err);

	assert(rc == 1);
	assert(g_fake.init_calls == 0);
	assert(out != NULL && strcmp(out, "") == 0);
	assert(err != NULL &&
	       strstr(err, "Refusing to run with mismatched real and effective "
			   "UIDs") != NULL);

	free(out);
	free(err);
}

typedef void (*test_fn)(void);

static void run_test(const char *name, test_fn fn)
{
	fn();
	fprintf(stdout, "ok - %s\n", name);
}

int main(void);

int main(void)
{
	run_test("requires_root", test_requires_root);
	run_test("init_failure", test_init_failure);
	run_test("successful_reset", test_successful_reset);
	run_test("mixed_failures_counted", test_mixed_failures_counted);
	run_test("reset_failure_closes_handle",
		 test_reset_failure_closes_handle);
	run_test("incomplete_ops_table_rejected",
		 test_incomplete_ops_table_rejected);
	run_test("product_name_sanitized", test_product_name_sanitized);
	run_test("null_device_entry_counted", test_null_device_entry_counted);
	run_test("mismatched_uids_rejected", test_mismatched_uids_rejected);

	return 0;
}
