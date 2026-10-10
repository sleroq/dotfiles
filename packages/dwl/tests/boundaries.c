/* Compile against the patched source: exercise real feature predicates without
 * starting a backend, creating an output, or disturbing an existing session. */
#define main dwl_main
#include "dwl.c"
#undef main
#include <assert.h>

static void
initial_maximize_request(void)
{
	struct wlr_surface surface = {0};
	struct wlr_xdg_toplevel toplevel = {0};
	struct wlr_xdg_surface xdg = {.surface = &surface, .toplevel = &toplevel};
	Client c = {.type = XDGShell, .surface.xdg = &xdg};
	toplevel.base = &xdg;
	toplevel.requested.maximized = 1;
	/* Initial requests precede the first surface commit. The initial commit
	 * will consume requested state; no configure is legal before that. */
	maximizenotify(&c.maximize, NULL);
	assert(!c.maximized && !toplevel.scheduled.maximized);
	toplevel.requested.maximized = 0;
	maximizenotify(&c.maximize, NULL);
	assert(!c.maximized && !toplevel.scheduled.maximized);
}

static void
initial_floating_placement(void)
{
	Monitor m = {.w = {72, 24, 1208, 696}};
	struct wlr_surface surface = {0};
	struct wlr_xdg_toplevel toplevel = {0};
	struct wlr_xdg_surface xdg = {.surface = &surface, .toplevel = &toplevel};
	Client c = {.type = XDGShell, .mon = &m, .isfloating = 1,
		.maximized = 1, .geom = {0, 0, 640, 480}, .surface.xdg = &xdg};
	/* Pre-map maximize must not save an uninitialized rectangle. */
	window_initial_placement(&c);
	assert(!c.initially_placed && c.maximize_restore.width == 0);
	surface.mapped = 1;
	window_initial_placement(&c);
	assert(c.initially_placed && c.geom.x == 356 && c.geom.y == 132);
	assert(c.maximize_restore.x == 356 && c.maximize_restore.y == 132);
	assert(c.maximize_restore.width == 640 && c.maximize_restore.height == 480);
	assert(c.floating_width == 640 && c.floating_height == 480);
	/* Arrange/maximize, workspace changes, and remaps must not recenter. */
	c.geom = m.w;
	window_initial_placement(&c);
	assert(c.geom.x == 72 && c.maximize_restore.x == 356);
	assert(c.floating_width == 640 && c.floating_height == 480);
	c.geom = c.maximize_restore;
	m.w.x = 200;
	window_initial_placement(&c);
	assert(c.geom.x == 356 && c.geom.width == 640);
	/* A tiled first map consumes the policy; later floating is user-owned. */
	c.initially_placed = c.isfloating = c.maximized = 0;
	c.geom = (struct wlr_box){10, 20, 420, 240};
	window_initial_placement(&c);
	assert(c.floating_width == 420 && c.floating_height == 240);
	c.isfloating = 1;
	window_initial_placement(&c);
	assert(c.geom.x == 10);
}

static void
directional_boundaries(void)
{
	Monitor m = {0};
	Client a = {0}, b = {0};
	struct wlr_box left, right;
	wl_list_init(&clients);
	m.tagset[0] = 1;
	m.ratio[0] = 0.63f;
	a.mon = b.mon = &m;
	a.tags = b.tags = 1;
	wl_list_insert(&clients, &b.link);
	wl_list_insert(&clients, &a.link);
	panes_reconcile(&m);
	/* A left split places selected singleton left and the old group right. */
	assert(pane_cross(&a, -1));
	panes_reconcile(&m);
	assert(a.pane == 0 && b.pane == 1);
	assert(!pane_cross(&a, -1) && !pane_cross(&b, 1));
	assert(pane_neighbor(0, -1) == -1 && pane_neighbor(1, 1) == -1);
	assert(pane_neighbor(0, 1) == 1 && pane_neighbor(1, -1) == 0);
	/* Deliberately interleave global order opposite the destination edge. */
	wl_list_remove(&b.link);
	wl_list_insert(&clients, &b.link);
	/* Inward crossing merges, collapses the empty pane, and keeps ratio. */
	assert(pane_cross(&a, 1));
	assert(a.link.next == &b.link);
	panes_reconcile(&m);
	assert(a.pane == 0 && b.pane == 0 && !m.tabs[0][1]);
	assert(m.ratio[0] == 0.63f);
	/* A right split leaves the old group left. */
	assert(pane_cross(&b, 1));
	panes_reconcile(&m);
	assert(a.pane == 0 && b.pane == 1);
	assert(pane_cross(&b, -1));
	assert(b.link.prev == &a.link);
	panes_reconcile(&m);
	assert(a.pane == 0 && b.pane == 0 && !m.tabs[0][1]);
	m.w = (struct wlr_box){0, 0, 1000, 800};
	left = tiled_geometry(&m, (struct wlr_box){0, 0, 630, 800});
	right = tiled_geometry(&m, (struct wlr_box){630, 0, 370, 800});
	assert(left.x == 8 && left.y == 4 && left.height == 792);
	assert(right.x - (left.x + left.width) == 4);
	assert(right.x + right.width == 992);
	left = tiled_geometry(&m, (struct wlr_box){0, 0, 1000, 400});
	right = tiled_geometry(&m, (struct wlr_box){0, 400, 1000, 400});
	assert(right.y - (left.y + left.height) == 4);
	assert(right.y + right.height == 796);
}

static void
floating_bounds(void)
{
	struct wlr_surface surface = {0};
	struct wlr_xdg_toplevel toplevel = {0};
	struct wlr_xdg_surface xdg = {.surface = &surface, .toplevel = &toplevel};
	Client c = {.type = XDGShell, .surface.xdg = &xdg, .isfloating = 1};
	struct wlr_box bounds = {100, 50, 800, 600};
	toplevel.base = &xdg;
	c.geom = (struct wlr_box){900, 650, 1200, 900};
	applybounds(&c, &bounds);
	assert(c.geom.x == 899 && c.geom.y == 649);
	c.geom.x = -1100;
	c.geom.y = -850;
	applybounds(&c, &bounds);
	assert(c.geom.x == -1099 && c.geom.y == -849);
	applybounds(&c, &bounds);
	assert(c.geom.x == -1099 && c.geom.y == -849);
}

int
main(void)
{
	Monitor m = {0};
	Client a = {0}, b = {0}, c = {0};
	struct xkb_context *context;
	struct xkb_keymap *keymap;
	struct wlr_keyboard_group *group;
	size_t i, j;
	/* Workspace and utility shortcuts must never shadow one another. */
	for (i = 0; i < LENGTH(keys); i++)
		for (j = i + 1; j < LENGTH(keys); j++)
			assert(keys[i].mod != keys[j].mod || keys[i].keysym != keys[j].keysym);
	wl_list_init(&clients);
	wl_list_init(&mons);
	wl_list_insert(&mons, &m.link);
	m.tagset[0] = 1;
	m.lt[0] = &layouts[0];
	m.grouped[0] = 1;
	m.ratio[0] = 0.63f;
	a.mon = b.mon = c.mon = &m;
	a.tags = b.tags = c.tags = 1;
	c.pane = 1;
	wl_list_insert(&clients, &c.link);
	wl_list_insert(&clients, &b.link);
	wl_list_insert(&clients, &a.link);
	panes_reconcile(&m);
	assert(group_navigation(&a));
	a.isfloating = 1;
	assert(!group_navigation(&a));
	a.isfloating = 0;
	a.overlay = 1;
	assert(!group_navigation(&a));
	a.overlay = 0;
	assert(client_visible(&a, &m));
	assert(!client_visible(&b, &m));
	assert(client_visible(&c, &m));
	/* Inactive tabs remain enumerated and retain ordinary workspace tags. */
	assert(wl_list_length(&clients) == 3 && b.tags == 1);
	m.tabs[0][0] = &b;
	panes_reconcile(&m);
	assert(!client_visible(&a, &m) && client_visible(&b, &m));
	/* Hidden overlay wins over sticky; show/hide never mutates tag membership. */
	b.overlay = b.isfloating = b.sticky = 1;
	m.overlay_focus = &b;
	panes_reconcile(&m);
	assert(!client_visible(&b, &m));
	m.overlay_open = 1;
	assert(client_visible(&b, &m));
	/* Explicit floating toggles must preserve overlay's always-floating mode. */
	selmon = &m;
	wl_list_init(&fstack);
	wl_list_insert(&fstack, &b.flink);
	togglefloating(NULL);
	assert(b.overlay && b.isfloating);
	wl_list_remove(&b.flink);
	m.tagset[0] = 2;
	assert(client_visible(&b, &m) && b.tags == 1);
	assert(!client_visible(&a, &m));
	m.overlay_open = 0;
	assert(!client_visible(&b, &m));
	/* Closing the first pane collapses the second without resetting ratio. */
	m.tagset[0] = 1;
	wl_list_remove(&a.link);
	window_forget(&a);
	panes_reconcile(&m);
	assert(c.pane == 0 && m.tabs[0][0] == &c && !m.tabs[0][1]);
	assert(m.ratio[0] == 0.63f);
	/* Unmap clears every saved focus/tab pointer, across workspaces. */
	m.underlay_focus = &b;
	m.tabs[5][1] = &b;
	window_forget(&b);
	assert(!m.overlay_focus && !m.underlay_focus && !m.tabs[5][1]);
	/* Public XKB APIs restore the effective layout on the actual keyboard. */
	context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
	keymap = xkb_keymap_new_from_names(context, &xkb_rules, XKB_KEYMAP_COMPILE_NO_FLAGS);
	assert(keymap);
	group = wlr_keyboard_group_create();
	assert(wlr_keyboard_set_keymap(&group->keyboard, keymap));
	window_keyboard_layout(&group->keyboard, 1);
	assert(group->keyboard.modifiers.group == 1);
	assert(xkb_state_serialize_layout(group->keyboard.xkb_state, XKB_STATE_LAYOUT_EFFECTIVE) == 1);
	window_keyboard_layout(&group->keyboard, 0);
	assert(group->keyboard.modifiers.group == 0);
	wlr_keyboard_group_destroy(group);
	xkb_keymap_unref(keymap);
	xkb_context_unref(context);
	assert(group_tab_index(32, 100, 3) == 0);
	assert(group_tab_index(33, 100, 3) == 1);
	assert(group_tab_index(65, 100, 3) == 1);
	assert(group_tab_index(66, 100, 3) == 2);
	floating_bounds();
	directional_boundaries();
	initial_maximize_request();
	initial_floating_placement();
	return 0;
}
