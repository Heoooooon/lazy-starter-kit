# docs/demo.tape — the README demo GIF, as code.
# Regenerate after flow changes:  brew install vhs && vhs docs/demo.tape
# (run from the repo root; writes docs/demo.gif)

Output docs/demo.gif

Set Shell "bash"
Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 15
Set Width 1200
Set Height 640
Set Padding 24
Set TypingSpeed 40ms
# palette matches docs/banner.png (bg #0c0e14, green ✓, periwinkle accent)
Set Theme { "name": "lazy-starter-kit", "background": "#0c0e14", "foreground": "#e8eaee", "cursor": "#aab8ff", "selection": "#33467c", "black": "#1d222e", "red": "#f7768e", "green": "#4ade80", "yellow": "#e0af68", "blue": "#6c9dff", "magenta": "#bb9af7", "cyan": "#7dcfff", "white": "#cdd2da", "brightBlack": "#6b7280", "brightRed": "#f7768e", "brightGreen": "#4ade80", "brightYellow": "#e0af68", "brightBlue": "#6c9dff", "brightMagenta": "#bb9af7", "brightCyan": "#7dcfff", "brightWhite": "#f5f6f8" }

# (not recorded) mask the recording machine's real git identity with a demo one
Hide
Type "export GIT_CONFIG_GLOBAL=/tmp/vhs-git; git config --file /tmp/vhs-git user.name 'Lazy Dev'; git config --file /tmp/vhs-git user.email 'lazy@example.com'; clear"
Enter
Show

# 1) the 7 steps at a glance
Type "./install.sh --list"
Sleep 400ms
Enter
Sleep 2.5s

Type "clear"
Enter

# 2) the full flow, previewed safely (nothing changes under --dry-run)
Type "./install.sh --dry-run"
Sleep 500ms
Enter
Sleep 7s

# hold the closing frame ("Done. That was a dry run …")
Sleep 5s
