/* Deterministic accounting regression against the actual patched compositor. */
#define main dwl_main
#include "dwl.c"
#undef main
#include <assert.h>

static void
near(double actual, double expected)
{
	assert(fabs(actual - expected) < 0.000001);
}

static void
accounting(void)
{
	MetricsApp app = {0};
	Client c = {.geom = {.width = 500, .height = 300}};
	wl_list_init(&clients);
	wl_list_insert(&clients, &c.link);
	memset(&metrics, 0, sizeof(metrics));
	metrics.path = "unused.prom";
	metrics.idle_after = 60;
	metrics.last = metrics.input = 100;
	c.metrics.app = &app;
	metrics.focus = &c;
	locked = 0;

	/* A delayed tick crosses the deadline: 60 active seconds, 10 idle. */
	metrics_account_at(170);
	near(metrics.state[0], 60);
	near(metrics.state[1], 10);
	near(c.metrics.focus[0], 60);
	near(app.focus[1], 10);
	near(c.metrics.mapped, 70);
	near(metrics.sizes[1][1], 70);
	assert(app.dwell_count == 0 && c.metrics.dwell_count == 0);
	metrics_end_dwell();
	assert(c.metrics.dwell_count == 1 && c.metrics.dwell[4] == 1);
	near(c.metrics.dwell_sum, 60);
	assert(app.dwell_count == 1 && app.dwell[4] == 1 && app.dwell[7] == 1);
	near(app.dwell_sum, 60);

	/* New input, then lock. Locked time cannot also be active or idle. */
	metrics.input = 170;
	metrics_account_at(180);
	metrics_end_dwell();
	locked = 1;
	metrics_account_at(280);
	near(metrics.state[0], 70);
	near(metrics.state[1], 10);
	near(metrics.state[2], 100);
	assert(app.dwell_count == 2);
	near(app.dwell_sum, 70);
	locked = 0;
	metrics_account_at(290);
	near(metrics.state[1], 20);
	near(metrics.state[0] + metrics.state[1] + metrics.state[2], 190);

	/* No focus still accrues mapped/unfocused time and session usage. */
	metrics.focus = NULL;
	metrics.input = 290;
	metrics_account_at(295);
	near(c.metrics.mapped, 195);
	near(c.metrics.focus[0] + c.metrics.focus[1] + c.metrics.focus[2], 190);
	near(metrics.state[0], 75);
	metrics.path = NULL;
	wl_list_remove(&c.link);
}

static void
size_and_pane_events(void)
{
	MetricsApp app = {0};
	Client c = {.geom = {.width = 500, .height = 300}};
	c.metrics.app = &app;
	metrics.path = "unused.prom";
	grabc = &c;
	cursor_mode = CurResize;
	metrics_resize(&c, 500, 300, 1); /* no size change */
	assert(!app.gestures && !app.resizes[1]);
	metrics_resize(&c, 490, 300, 1);
	metrics_resize(&c, 480, 290, 1);
	assert(app.gestures == 1 && app.resizes[1] == 2);
	c.metrics.grab_changed = 0;
	metrics_resize(&c, 480, 290, 1);
	assert(app.gestures == 2 && c.metrics.gestures == 2);
	metrics_resize(&c, 480, 290, 0);
	assert(app.resizes[0] == 1);
	metrics_pane(&c, 1);
	metrics_pane(&c, 0);
	assert(app.splits == 1 && app.pane_moves == 2);
	assert(c.metrics.splits == 1 && c.metrics.pane_moves == 2);
	grabc = NULL;
	cursor_mode = CurNormal;
	metrics.path = NULL;
}

static void
real_pane_crossings(void)
{
	MetricsApp app = {0};
	Monitor m = {.tagset = {1, 1}};
	Client c = {.mon = &m, .tags = 1}, peer = {.mon = &m, .tags = 1};
	c.metrics.app = &app;
	metrics.path = "unused.prom";
	wl_list_init(&clients);
	wl_list_insert(&clients, &c.link);
	m.tabs[0][0] = &c;
	assert(pane_cross(&c, 1));
	panes_reconcile(&m);
	assert(app.splits == 0 && app.pane_moves == 1);
	assert(pane_cross(&c, -1));
	panes_reconcile(&m);
	assert(app.splits == 0 && app.pane_moves == 2);
	wl_list_insert(&clients, &peer.link);
	assert(pane_cross(&c, 1));
	panes_reconcile(&m);
	assert(app.splits == 1 && app.pane_moves == 3);
	assert(m.tabs[0][0] && m.tabs[0][1]);
	wl_list_remove(&peer.link);
	wl_list_remove(&c.link);
	metrics.path = NULL;
}

static void
escaping(void)
{
	char output[128] = {0};
	FILE *f = tmpfile();
	assert(f);
	metrics_label(f, "a\"b\\c\nd");
	rewind(f);
	assert(fread(output, 1, sizeof(output) - 1, f) == 12);
	assert(!strcmp(output, "\"a\\\"b\\\\c\\nd\""));
	fclose(f);
}

int
main(void)
{
	accounting();
	size_and_pane_events();
	real_pane_crossings();
	escaping();
	puts("PASS: exact idle/lock accounting, focus retention, size events and label escaping");
	return 0;
}
