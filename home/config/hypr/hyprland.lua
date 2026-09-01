-- Home Manager registers hy3 before the main configuration. On a cold start,
-- Hyprland loads newly registered plugins and then evaluates this file again.
dofile(os.getenv("HOME") .. "/.config/hypr/extra-config.lua")
local hy3 = hl.plugin.hy3

-------------------
-- My programs
-------------------

local fastTerminal = "kitty"
local fileManager = "uwsm-app -- nemo"

local menu = "tofi-drun --drun-launch=false | xargs --no-run-if-empty uwsm-app --"
local menuBin = "tofi-run | xargs --no-run-if-empty uwsm-app --"
local menuApp = "vicinae"
local menuWindows = "vicinae vicinae://extensions/vicinae/wm/switch-windows"
local menuClipboard = "vicinae vicinae://extensions/vicinae/clipboard/history"

-------------------
-- Autostart
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm-app -- systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("uwsm app -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -- hyprland-per-window-layout")
    hl.exec_cmd("uwsm app -- flameshot")
    hl.exec_cmd("uwsm app -s b -- swww-daemon")
    hl.exec_cmd("uwsm app -- keepassxc", { workspace = "4 silent" })
    hl.exec_cmd("uwsm app -- noisetorch", { workspace = "10 silent" })
end)

-------------------------
-- Environment variables
-------------------------

hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "gtk")
hl.env("NIXOS_OZONE_WL", "1")
hl.env("SSH_AUTH_SOCK", "/run/user/1000/ssh-agent")

-------------------
-- Look and feel
-------------------

hl.config({
    xwayland = {
        enabled = true,
    },
    debug = {
        vfr = true,
    },
    general = {
        gaps_in = 4,
        gaps_out = { top = 4, right = 8, bottom = 4, left = 8 },
        border_size = 2,
        col = {
            active_border = {
                colors = { "rgba(a288b9ee)", "rgba(c5a9d6ee)" },
                angle = 45,
            },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = true,
        layout = "hy3",
        snap = {
            enabled = true,
        },
    },
    decoration = {
        rounding = 5,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        blur = {
            enabled = false,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
    plugin = hy3 and {
        hy3 = {
            tabs = {
                height = 6,
                padding = 6,
                render_text = false,
                colors = {
                    active_border = "rgba(c5a9d6ee)",
                },
            },
            autotile = {
                enable = true,
                trigger_width = 800,
                trigger_height = 500,
            },
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        enable_anr_dialog = false,
    },
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:lctrl_lwin_toggle,ctrl:nocaps",
        follow_mouse = 2,
        accel_profile = "flat",
        sensitivity = 0,
        repeat_delay = 250,
        repeat_rate = 25,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.2,
        },
    },
})

hl.animation({ leaf = "windows", enabled = true, speed = 1, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "default", style = "slidefade" })

-------------------
-- Keybindings
-------------------

local super = "SUPER"

local function bind(keys, dispatcher, flags)
    -- The launcher catchall requires a submap. Keep normal desktop bindings
    -- active while that persistent base submap is selected.
    flags = flags or {}
    flags.submap_universal = true
    hl.bind(keys, dispatcher, flags)
end

local function exec(keys, command, flags)
    bind(keys, hl.dsp.exec_cmd(command), flags)
end

exec(super .. " + Return", fastTerminal)
bind("ALT + Return", hl.dsp.exec_cmd(fastTerminal, { float = true }))

exec(super .. " + P", menu)
exec(super .. " + semicolon", menuApp)
exec(super .. " + SHIFT + P", menuBin)
exec(super .. " + Z", menuClipboard)
exec(super .. " + Tab", menuWindows)

exec(super .. " + F8", "uwsm-app -- hypr-follow-mouse-toggle")
exec(super .. " + F9", "uwsm-app -- hypr-gamemode")
exec(super .. " + y", fileManager)

exec("Print", "flameshot gui")
exec("SHIFT + Print", "flameshot full -c -p ~/Pictures/Screenshots")
exec(super .. " + Print", "share-screenshot")

exec("XF86MonBrightnessUp", "uwsm-app -- light -A 5")
exec("XF86MonBrightnessDown", "uwsm-app -- light -U 5")
exec("XF86AudioRaiseVolume", "uwsm-app -- pactl set-sink-volume @DEFAULT_SINK@ +5%")
exec("XF86AudioLowerVolume", "uwsm-app -- pactl set-sink-volume @DEFAULT_SINK@ -5%")
exec("XF86AudioMute", "uwsm-app -- mic-mute-toggle")
exec("XF86Calculator", "uwsm-app -- mic-mute-toggle")
exec(super .. " + M", "uwsm-app -- mic-mute-toggle")

bind(super .. " + SHIFT + C", hl.dsp.window.close())
exec(super .. " + SHIFT + N", "caelestia shell drawers toggle sidebar")
bind(super .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
bind(super .. " + CTRL + Y", hl.dsp.window.pin({ action = "toggle" }))
bind(super .. " + V", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind(super .. " + SHIFT + V", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

local directions = {
    { direction = "l", keys = { "left", "H" } },
    { direction = "r", keys = { "right", "L" } },
    { direction = "u", keys = { "up", "K" } },
    { direction = "d", keys = { "down", "J" } },
}

if hy3 then
    for _, entry in ipairs(directions) do
        for _, key in ipairs(entry.keys) do
            bind(super .. " + " .. key, hy3.move_focus(entry.direction))
        end
    end

    bind(super .. " + U", hy3.make_group("h"))
    bind(super .. " + C", hy3.make_group("v"))
    bind(super .. " + B", hy3.make_group("tab"))
    bind(super .. " + A", hy3.change_focus("raise"))
    bind(super .. " + SHIFT + A", hy3.change_focus("lower"))
    bind(super .. " + I", hy3.expand("expand"))
    bind(super .. " + SHIFT + I", hy3.expand("shrink"))
end

bind(super .. " + O", hl.dsp.global("caelestia:launcher"))
bind("CTRL + ALT + L", hl.dsp.global("caelestia:lock"))

local interruptFlags = { ignore_mods = true, non_consuming = true }
hl.define_submap("global", function()
    for _, key in ipairs({
        "catchall",
        "mouse:272",
        "mouse:273",
        "mouse:274",
        "mouse:275",
        "mouse:276",
        "mouse:277",
        "mouse_up",
        "mouse_down",
    }) do
        bind(key, hl.dsp.global("caelestia:launcherInterrupt"), interruptFlags)
    end
end)

hl.on("hyprland.start", function()
    hl.dispatch(hl.dsp.submap("global"))
end)

if hy3 then
    for _, entry in ipairs(directions) do
        for _, key in ipairs(entry.keys) do
            bind(super .. " + SHIFT + " .. key, hy3.move_window(entry.direction, { once = true }))
            bind(super .. " + CTRL + SHIFT + " .. key, hy3.move_window(entry.direction, {
                once = true,
                visible = true,
            }))
        end
    end

    for workspace = 1, 10 do
        local key = workspace % 10
        bind(super .. " + " .. key, hy3.move_to_workspace(tostring(workspace)))
    end
end

local workspaceKeys = { "Q", "W", "E", "R", "T", "A", "S", "D", "F", "G" }
for workspace, key in ipairs(workspaceKeys) do
    bind(super .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
end

bind(super .. " + X", hl.dsp.workspace.toggle_special("magic"))
bind(super .. " + SHIFT + X", hl.dsp.window.move({ workspace = "special:magic" }))
bind(super .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
bind(super .. " + SHIFT + mouse_up", hl.dsp.focus({ workspace = "e+1" }))
bind(super .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(super .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------------
-- Windows and workspaces
--------------------------

local function windowRule(match, effects)
    effects.match = match
    hl.window_rule(effects)
end

windowRule({ class = "org.keepassxc.KeePassXC" }, {
    no_screen_share = true,
    float = true,
    size = { "monitor_w * 0.6", "monitor_h * 0.7" },
})

windowRule({ class = "com.discordapp.DiscordCanary" }, {
    float = true,
    size = { "monitor_w * 0.6", "monitor_h * 0.7" },
    move = { "monitor_w * 0.2", "monitor_h * 0.15" },
})

windowRule({ class = "pwvucontrol|com.saivert.pwvucontrol|nm-connection-editor" }, {
    float = true,
    move = { "monitor_w * 0.7", 36 },
    size = { 564, "monitor_h * 0.34" },
})

for _, class in ipairs({ "Signal", "org.telegram.desktop", "vesktop", "nemo" }) do
    windowRule({ class = class }, { float = true })
end

windowRule({ class = "org.telegram.desktop", title = "Media viewer" }, {
    size = { "monitor_w", "monitor_h" },
})

for _, title in ipairs({ "Find Directory", "File Upload", "Choose Files", "Save \\w+" }) do
    windowRule({ title = title }, { float = true })
end

windowRule({ workspace = "special:magic" }, { float = true })

for _, class in ipairs({ "org\\.https:\\/\\/nomacs\\.", "mpv" }) do
    windowRule({ class = class }, { fullscreen = true })
end

windowRule({ class = ".*" }, { suppress_event = "maximize" })

for _, match in ipairs({
    { class = "^(gamescope).*" },
    { class = "^(steam_app_).*" },
    { class = "^(steam_).*" },
    { title = "^(Veloren)$" },
}) do
    windowRule(match, { immediate = true })
end

windowRule({ class = "^(flameshot)$" }, { no_anim = true, float = true })
windowRule({ class = "^(steam)$", title = "^(Friends List)$" }, { float = true })

hl.layer_rule({ match = { namespace = "vicinae" }, no_screen_share = true })
hl.layer_rule({
    match = { namespace = "caelestia-(border-exclusion|area-picker)" },
    no_anim = true,
})
hl.layer_rule({
    match = { namespace = "caelestia-(drawers|background)" },
    animation = "fade",
})
hl.layer_rule({
    match = { namespace = "caelestia-drawers" },
    blur = true,
    ignore_alpha = 0.57,
})
