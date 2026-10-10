/* Taken from https://github.com/djpohly/dwl/issues/466 */
#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }
/* appearance */
static int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;  /* 1 means idle inhibitors will disable idle tracking even if it's surface isn't visible  */
static const unsigned int borderpx         = 2;  /* border pixel of windows */
static const unsigned int snap             = 32; /* snap pixel */
static const float rootcolor[]             = COLOR(0x222222ff);
static const float bordercolor[]           = COLOR(0xa288b9ff);
static const float focuscolor[]            = COLOR(0xc5a9d6ff);
static const float urgentcolor[]           = COLOR(0xff0000ff);
/* This conforms to the xdg-protocol. Set the alpha to zero to restore the old behavior */
static const float fullscreen_bg[]         = {0.0f, 0.0f, 0.0f, 1.0f}; /* You can also use glsl colors */

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (10)

/* logging */
static int log_level = WLR_ERROR;

/* window resizing: 0 TL, 1 TR, 2 BL, 3 BR, 4 nearest corner */
static const int resize_corner = 4;
static const int warp_cursor = 0;
static const int lock_cursor = 0;

static const Rule rules[] = {
	/* Explicit one-off floating terminal identity, not an application rule. */
	{ "dwl-floating-terminal", NULL, 0, 1, -1 },
};

/* layout(s) */
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* monitors */
/* (x=-1, y=-1) is reserved as an "autoconfigure" monitor position indicator
 * WARNING: negative values other than (-1, -1) cause problems with Xwayland clients due to
 * https://gitlab.freedesktop.org/xorg/xserver/-/issues/899 */
static const MonitorRule monrules[] = {
   /* name        mfact  nmaster scale layout       rotate/reflect                x    y
    * example of a HiDPI laptop monitor:
    { "eDP-1",    0.5f,  1,      2,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 }, */
	{ NULL,       0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
	/* default monitor rule: can be changed but cannot be eliminated; at least one monitor rule must exist */
};

/* keyboard */
static const struct xkb_rule_names xkb_rules = {
	/* can specify fields: rules, model, layout, variant, options */
	/* example:
	.options = "ctrl:nocaps",
	*/
	.layout = "us,ru",
	.options = "ctrl:nocaps,grp:lctrl_lwin_toggle",
};

static const int repeat_rate = 25;
static const int repeat_delay = 250;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 1; /* Touchpads only; mice use normal scrolling. */
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
/* You can choose between:
LIBINPUT_CONFIG_SCROLL_NO_SCROLL
LIBINPUT_CONFIG_SCROLL_2FG
LIBINPUT_CONFIG_SCROLL_EDGE
LIBINPUT_CONFIG_SCROLL_ON_BUTTON_DOWN
*/
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;

/* You can choose between:
LIBINPUT_CONFIG_CLICK_METHOD_NONE
LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS
LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER
*/
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;

/* You can choose between:
LIBINPUT_CONFIG_SEND_EVENTS_ENABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED
LIBINPUT_CONFIG_SEND_EVENTS_DISABLED_ON_EXTERNAL_MOUSE
*/
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;

/* You can choose between:
LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT
LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE
*/
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT;
static const double accel_speed = 0.0;

/* You can choose between:
LIBINPUT_CONFIG_TAP_MAP_LRM -- 1/2/3 finger tap maps to left/right/middle
LIBINPUT_CONFIG_TAP_MAP_LMR -- 1/2/3 finger tap maps to left/middle/right
*/
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* If you want to use the windows key for MODKEY, use WLR_MODIFIER_LOGO */
#define MODKEY WLR_MODIFIER_LOGO

#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,            toggleview,      {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, KEY,            tag,             {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,KEY,toggletag,  {.ui = 1 << TAG} }

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

static const Key keys[] = {
	{ MODKEY, XKB_KEY_Return, spawn, {.v = (const char *[]) {"uwsm-app", "--", "kitty", "--single-instance", "--instance-group", "dwl", "--override", "remember_window_size=no", NULL}} },
	{ WLR_MODIFIER_ALT, XKB_KEY_Return, spawn, {.v = (const char *[]) {"uwsm-app", "--", "kitty", "--single-instance", "--instance-group", "dwl", "--override", "remember_window_size=no", "--class", "dwl-floating-terminal", NULL}} },
	{ MODKEY, XKB_KEY_p, spawn, {.v = (const char *[]) {"noctalia", "msg", "panel-toggle", "launcher", NULL}} },
	{ MODKEY, XKB_KEY_o, spawn, {.v = (const char *[]) {"noctalia", "msg", "panel-toggle", "launcher", NULL}} },
	{ MODKEY, XKB_KEY_semicolon, spawn, {.v = (const char *[]) {"noctalia", "msg", "panel-toggle", "launcher", NULL}} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_p, spawn, {.v = (const char *[]) {"noctalia", "msg", "panel-toggle", "launcher", "/run", NULL}} },
	{ MODKEY, XKB_KEY_z, spawn, {.v = (const char *[]) {"noctalia", "msg", "panel-toggle", "clipboard", NULL}} },
	{ MODKEY, XKB_KEY_y, spawn, {.v = (const char *[]) {"uwsm-app", "--", "nemo", NULL}} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_l, spawn, {.v = (const char *[]) {"noctalia", "msg", "session", "lock", NULL}} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_n, spawn, {.v = (const char *[]) {"noctalia", "msg", "panel-toggle", "control-center", "notifications", NULL}} },
	{ MODKEY, XKB_KEY_b, groupmode, {0} },
	{ MODKEY, XKB_KEY_x, overlaytoggle, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_v, maximizetoggle, {0} },
	{ MODKEY, XKB_KEY_v, togglefullscreen, {0} },
	{ MODKEY, XKB_KEY_u, grouporientation, {.i = 0} },
	{ MODKEY, XKB_KEY_c, grouporientation, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_a, groupselect, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_x, overlaysend, {0} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_y, stickyToggle, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space, togglefloating, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_c, killclient, {0} },
	{ MODKEY, XKB_KEY_F8, focusfollowtoggle, {0} },
	{ MODKEY, XKB_KEY_m, spawn, {.v = (const char *[]) {"noctalia", "msg", "mic-mute", NULL}} },
	{ MODKEY, XKB_KEY_h, tabcycle, {.i = -1} },
	{ MODKEY, XKB_KEY_Left, tabcycle, {.i = -1} },
	{ MODKEY, XKB_KEY_l, tabcycle, {.i = 1} },
	{ MODKEY, XKB_KEY_Right, tabcycle, {.i = 1} },
	{ MODKEY, XKB_KEY_j, panefocus, {.i = 1} },
	{ MODKEY, XKB_KEY_Down, panefocus, {.i = 1} },
	{ MODKEY, XKB_KEY_k, panefocus, {.i = -1} },
	{ MODKEY, XKB_KEY_Up, panefocus, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_h, groupreorder, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_l, groupreorder, {.i = 1} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_h, setmfact, {.f = -0.05f} },
	{ MODKEY|WLR_MODIFIER_CTRL, XKB_KEY_l, setmfact, {.f = 0.05f} },
	{ MODKEY, XKB_KEY_q, view, {.ui = 1 << 0} },
	{ MODKEY, XKB_KEY_w, view, {.ui = 1 << 1} },
	{ MODKEY, XKB_KEY_e, view, {.ui = 1 << 2} },
	{ MODKEY, XKB_KEY_r, view, {.ui = 1 << 3} },
	{ MODKEY, XKB_KEY_t, view, {.ui = 1 << 4} },
	{ MODKEY, XKB_KEY_a, view, {.ui = 1 << 5} },
	{ MODKEY, XKB_KEY_s, view, {.ui = 1 << 6} },
	{ MODKEY, XKB_KEY_d, view, {.ui = 1 << 7} },
	{ MODKEY, XKB_KEY_f, view, {.ui = 1 << 8} },
	{ MODKEY, XKB_KEY_g, view, {.ui = 1 << 9} },
	{ MODKEY, XKB_KEY_1, workspacetag, {.ui = 1 << 0} },
	{ MODKEY, XKB_KEY_2, workspacetag, {.ui = 1 << 1} },
	{ MODKEY, XKB_KEY_3, workspacetag, {.ui = 1 << 2} },
	{ MODKEY, XKB_KEY_4, workspacetag, {.ui = 1 << 3} },
	{ MODKEY, XKB_KEY_5, workspacetag, {.ui = 1 << 4} },
	{ MODKEY, XKB_KEY_6, workspacetag, {.ui = 1 << 5} },
	{ MODKEY, XKB_KEY_7, workspacetag, {.ui = 1 << 6} },
	{ MODKEY, XKB_KEY_8, workspacetag, {.ui = 1 << 7} },
	{ MODKEY, XKB_KEY_9, workspacetag, {.ui = 1 << 8} },
	{ MODKEY, XKB_KEY_0, workspacetag, {.ui = 1 << 9} },
	{ 0, XKB_KEY_Print, spawn, {.v = (const char *[]) {"flameshot", "gui", NULL}} },
	{ WLR_MODIFIER_SHIFT, XKB_KEY_Print, spawn, SHCMD("flameshot full -c -p \"$HOME/Pictures/Screenshots\"") },
	{ MODKEY, XKB_KEY_Print, spawn, {.v = (const char *[]) {"share-screenshot", NULL}} },
	{ 0, XKB_KEY_XF86AudioRaiseVolume, spawn, {.v = (const char *[]) {"noctalia", "msg", "volume-up", "5", NULL}} },
	{ 0, XKB_KEY_XF86AudioLowerVolume, spawn, {.v = (const char *[]) {"noctalia", "msg", "volume-down", "5", NULL}} },
	{ 0, XKB_KEY_XF86AudioMute, spawn, {.v = (const char *[]) {"noctalia", "msg", "mic-mute", NULL}} },
	{ 0, XKB_KEY_XF86Calculator, spawn, {.v = (const char *[]) {"noctalia", "msg", "mic-mute", NULL}} },
	{ 0, XKB_KEY_XF86AudioMicMute, spawn, {.v = (const char *[]) {"noctalia", "msg", "mic-mute", NULL}} },
	{ 0, XKB_KEY_XF86MonBrightnessUp, spawn, {.v = (const char *[]) {"noctalia", "msg", "brightness-up", "current", "5", NULL}} },
	{ 0, XKB_KEY_XF86MonBrightnessDown, spawn, {.v = (const char *[]) {"noctalia", "msg", "brightness-down", "current", "5", NULL}} },
	{ 0, XKB_KEY_XF86AudioPlay, spawn, {.v = (const char *[]) {"noctalia", "msg", "media", "toggle", NULL}} },
	{ 0, XKB_KEY_XF86AudioNext, spawn, {.v = (const char *[]) {"noctalia", "msg", "media", "next", NULL}} },
	{ 0, XKB_KEY_XF86AudioPrev, spawn, {.v = (const char *[]) {"noctalia", "msg", "media", "previous", NULL}} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F1, chvt, {.ui = 1} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F2, chvt, {.ui = 2} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F3, chvt, {.ui = 3} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F4, chvt, {.ui = 4} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F5, chvt, {.ui = 5} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F6, chvt, {.ui = 6} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F7, chvt, {.ui = 7} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F8, chvt, {.ui = 8} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F9, chvt, {.ui = 9} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F10, chvt, {.ui = 10} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F11, chvt, {.ui = 11} },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_F12, chvt, {.ui = 12} },
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};

static const Axis axes[] = {
	{ MODKEY|WLR_MODIFIER_SHIFT, AxisUp, workspacestep, {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, AxisDown, workspacestep, {.i = 1} },
	{ MODKEY, AxisUp, setmfact, {.f = 0.05f} },
	{ MODKEY, AxisDown, setmfact, {.f = -0.05f} },
};
