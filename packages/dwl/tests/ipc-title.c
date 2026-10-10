/* One-shot focused-title snapshot for the disposable headless transition tests. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "dwl-ipc.h"

static struct wl_output *output;
static struct zdwl_ipc_manager_v2 *manager;
static char *title;

static int
ipc_event(const void *implementation, void *target, uint32_t opcode,
          const struct wl_message *message, union wl_argument *arguments)
{
	(void)implementation;
	(void)target;
	(void)opcode;
	if (!strcmp(message->name, "title")) {
		free(title);
		title = strdup(arguments[0].s);
	}
	return 0;
}

static void
global(void *data, struct wl_registry *registry, uint32_t name,
       const char *interface, uint32_t version)
{
	(void)data;
	(void)version;
	if (!output && !strcmp(interface, "wl_output"))
		output = wl_registry_bind(registry, name, &wl_output_interface, 1);
	if (!manager && !strcmp(interface, "zdwl_ipc_manager_v2")) {
		manager = wl_registry_bind(registry, name, &zdwl_ipc_manager_v2_interface, 1);
		wl_proxy_add_dispatcher((struct wl_proxy *)manager, ipc_event, NULL, NULL);
	}
}

static void
removed(void *data, struct wl_registry *registry, uint32_t name)
{
	(void)data;
	(void)registry;
	(void)name;
}

int
main(void)
{
	const struct wl_registry_listener listener = {global, removed};
	struct wl_display *display = wl_display_connect(NULL);
	struct wl_registry *registry;
	struct zdwl_ipc_output_v2 *ipc_output;
	int result = EXIT_FAILURE;

	if (!display) {
		fputs("ipc-title: cannot connect to Wayland\n", stderr);
		return result;
	}
	registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &listener, NULL);
	if (wl_display_roundtrip(display) < 0 || !output || !manager) {
		fputs("ipc-title: cannot discover DWL IPC output\n", stderr);
		goto done;
	}
	ipc_output = zdwl_ipc_manager_v2_get_output(manager, output);
	wl_proxy_add_dispatcher((struct wl_proxy *)ipc_output, ipc_event, NULL, NULL);
	if (wl_display_roundtrip(display) < 0) {
		fputs("ipc-title: cannot read title snapshot\n", stderr);
	} else {
		puts(title ? title : "");
		result = EXIT_SUCCESS;
	}
	zdwl_ipc_output_v2_release(ipc_output);
done:
	if (manager)
		zdwl_ipc_manager_v2_release(manager);
	if (output)
		wl_output_destroy(output);
	wl_registry_destroy(registry);
	wl_display_disconnect(display);
	free(title);
	return result;
}
