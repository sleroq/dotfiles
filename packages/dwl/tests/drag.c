/* A held-button move across commits/release, or one interactive size change. */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "virtual-pointer.h"

static struct zwlr_virtual_pointer_manager_v1 *manager;

static void
global(void *data, struct wl_registry *registry, uint32_t name,
		const char *interface, uint32_t version)
{
	(void)data;
	(void)version;
	if (!strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name))
		manager = wl_registry_bind(registry, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}

static void removed(void *data, struct wl_registry *registry, uint32_t name)
{
	(void)data;
	(void)registry;
	(void)name;
}

static void
checkpoint(struct wl_display *display, const char *stage)
{
	assert(wl_display_roundtrip(display) >= 0);
	puts(stage);
	fflush(stdout);
	assert(getchar() == '\n');
}

int
main(int argc, char **argv)
{
	int resizing = argc > 1 && !strcmp(argv[1], "resize");
	int quadrant = resizing && argc > 2 ? atoi(argv[2]) : 3;
	int xoffset = resizing && argc > 3 ? atoi(argv[3]) : 0;
	int yoffset = resizing && argc > 4 ? atoi(argv[4]) : 0;
	int dx = argc > 2 ? 35 : 140;
	int dy = argc > 2 ? 15 : 60;
	assert(quadrant >= 0 && quadrant < 4);
	uint32_t button = resizing ? 273 : 272;
	struct wl_display *display = wl_display_connect(NULL);
	struct wl_registry *registry;
	struct zwlr_virtual_pointer_v1 *pointer;
	const struct wl_registry_listener listener = {global, removed};
	assert(display);
	registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &listener, NULL);
	assert(wl_display_roundtrip(display) >= 0 && manager);
	pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
	zwlr_virtual_pointer_v1_motion_absolute(pointer, 1,
		resizing ? xoffset + (quadrant & 1 ? 450 : 100) : 500,
		resizing ? yoffset + (quadrant & 2 ? 250 : 100) : 300, 1280, 720);
	zwlr_virtual_pointer_v1_frame(pointer);
	zwlr_virtual_pointer_v1_button(pointer, 2, button, WL_POINTER_BUTTON_STATE_PRESSED);
	zwlr_virtual_pointer_v1_frame(pointer);
	zwlr_virtual_pointer_v1_motion(pointer, 3,
		wl_fixed_from_int(resizing ? (quadrant & 1 ? dx : -dx) : 3000),
		wl_fixed_from_int(resizing ? (quadrant & 2 ? dy : -dy) : 0));
	zwlr_virtual_pointer_v1_frame(pointer);
	if (!resizing) {
		checkpoint(display, "outside");
		zwlr_virtual_pointer_v1_motion(pointer, 4, wl_fixed_from_int(1), 0);
		zwlr_virtual_pointer_v1_frame(pointer);
		checkpoint(display, "commit");
	}
	zwlr_virtual_pointer_v1_button(pointer, 5, button, WL_POINTER_BUTTON_STATE_RELEASED);
	zwlr_virtual_pointer_v1_frame(pointer);
	if (resizing) assert(wl_display_roundtrip(display) >= 0);
	else checkpoint(display, "release");
	zwlr_virtual_pointer_v1_destroy(pointer);
	zwlr_virtual_pointer_manager_v1_destroy(manager);
	wl_registry_destroy(registry);
	wl_display_disconnect(display);
	return 0;
}
