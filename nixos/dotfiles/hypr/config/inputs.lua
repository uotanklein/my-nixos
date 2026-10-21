-- Input configuration

hl.config({
    input = {
        -- This keymap mirrors kb_layout/kb_options below and fixes Caps Lock release delay.
        kb_file = os.getenv("HOME") .. "/.config/hypr/keymaps/caps-immediate.xkb",
        kb_layout = "us,ru",
        kb_options = "grp:win_space_toggle,grp:alt_shift_toggle",
        -- sensitivity = -0.25,
        accel_profile = "flat",
    },
    -- Uncomment the section below to enable software cursors; this can help with cursor display or behavior issues
    -- cursor = {
    --     no_hardware_cursors = 1,
    -- },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })
