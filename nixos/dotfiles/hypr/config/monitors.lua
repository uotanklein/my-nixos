-- Physical layout, left to right. Side displays are vertically centered.
hl.monitor({
    output = "HDMI-A-1", -- Samsung S24D332: left
    mode = "1920x1080@74.97",
    position = "0x180",
    scale = "1",
})

hl.monitor({
    output = "DP-2", -- MSI G274QPF: center
    mode = "2560x1440@165",
    position = "1920x0",
    scale = "1",
})

hl.monitor({
    output = "DP-1", -- MSI MP275 E2: right
    mode = "1920x1080@60",
    position = "4480x180",
    scale = "1",
})

-- Default for any additional display.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
