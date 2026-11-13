-- mode: normal
-- Managed by scripts/ChangeBlur.sh (SUPER+ALT+O) -- don't edit by hand.
hl.config({ decoration = { blur = { size = 5, passes = 2 } } })
hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override 1.0 override" })
