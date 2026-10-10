#include <gtk/gtk.h>
#include <stdio.h>

static gboolean
window_state(GtkWidget *widget, GdkEventWindowState *event, gpointer data)
{
	(void)widget;
	(void)data;
	printf("GTK maximized=%d\n", !!(event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED));
	fflush(stdout);
	return FALSE;
}

static void
size_allocate(GtkWidget *widget, GtkAllocation *allocation, gpointer data)
{
	(void)widget;
	(void)data;
	printf("GTK size=%dx%d\n", allocation->width, allocation->height);
	fflush(stdout);
}

static gboolean
dialog(GtkWidget *parent, GdkEventKey *event, gpointer data)
{
	GtkWidget *child;
	(void)data;
	if (event->keyval != GDK_KEY_d)
		return FALSE;
	child = gtk_dialog_new_with_buttons("DWL-transient-test", GTK_WINDOW(parent),
		GTK_DIALOG_MODAL, "Close", GTK_RESPONSE_CLOSE, NULL);
	gtk_window_set_default_size(GTK_WINDOW(child), 360, 180);
	gtk_container_add(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(child))),
		gtk_label_new("Overlay dialog fixture"));
	g_signal_connect_swapped(child, "response", G_CALLBACK(gtk_widget_destroy), child);
	gtk_widget_show_all(child);
	return TRUE;
}

static gboolean
pointer_enter(GtkWidget *widget, GdkEventCrossing *event, gpointer data)
{
	(void)widget;
	(void)data;
	printf("GTK pointer=%.0f,%.0f\n", event->x, event->y);
	fflush(stdout);
	return FALSE;
}

static gboolean
application_click(GtkWidget *widget, GdkEventButton *event, gpointer data)
{
	(void)widget;
	(void)data;
	printf("GTK button=%u\n", event->button);
	fflush(stdout);
	return FALSE;
}

int
main(int argc, char **argv)
{
	GtkWidget *parent;
	int underlay = argc > 1 && !g_strcmp0(argv[1], "underlay");
	int ordinary = argc > 1 && !g_strcmp0(argv[1], "ordinary");
	int named = argc > 2;
	int maximize = argc > 1 && !g_strcmp0(argv[1], "maximize");
	int oversized = argc > 1 && !g_strcmp0(argv[1], "oversized");
	g_set_prgname(underlay ? "dwl-underlay-test" : ordinary ? "dwl-ordinary-test" : "dwl-floating-terminal");
	gtk_init(&argc, &argv);
	parent = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title(GTK_WINDOW(parent), named ? argv[2] : underlay ? "DWL-underlay-test" : "DWL-parent-test");
	gtk_window_set_default_size(GTK_WINDOW(parent),
		oversized ? 1800 : 500, oversized ? 1000 : 300);
	gtk_container_add(GTK_CONTAINER(parent), gtk_label_new("Press d for dialog"));
	g_signal_connect(parent, "key-press-event", G_CALLBACK(dialog), NULL);
	g_signal_connect(parent, "destroy", G_CALLBACK(gtk_main_quit), NULL);
	g_signal_connect(parent, "window-state-event", G_CALLBACK(window_state), NULL);
	g_signal_connect(parent, "size-allocate", G_CALLBACK(size_allocate), NULL);
	if (underlay)
		gtk_window_fullscreen(GTK_WINDOW(parent));
	if (maximize)
		gtk_window_maximize(GTK_WINDOW(parent));
	gtk_widget_add_events(parent, GDK_BUTTON_PRESS_MASK | GDK_ENTER_NOTIFY_MASK);
	g_signal_connect(parent, "enter-notify-event", G_CALLBACK(pointer_enter), NULL);
	g_signal_connect(parent, "button-press-event", G_CALLBACK(application_click), NULL);
	gtk_widget_show_all(parent);
	gtk_main();
	return 0;
}
