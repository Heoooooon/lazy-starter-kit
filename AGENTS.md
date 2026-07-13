# Safety rules for coding agents

- Never run `rm -r`, `rm -rf`, `rm -R`, or `rm --recursive` directly.
- Use `lazy-safe-rm` for recursive cleanup. It only accepts strict descendants of the current Git workspace.
- Never bypass the Codex or Claude Code shell-safety hook, including through `/bin/rm`, `sudo`, `env`, `xargs`, or a nested shell.
- Product cleanup code must use `safe_rm_rf_under` on macOS/Linux or `Remove-KitTree` on Windows.
- Preserve unrelated working-tree changes and local-only agent settings.
