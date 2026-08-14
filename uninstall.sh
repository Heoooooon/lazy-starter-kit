#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'EOF'
lazy-starter-kit uninstall has been removed.

The previous uninstaller could not reliably distinguish tools installed by
lazy-starter-kit from tools that already existed on the machine. To avoid
removing user-owned software or configuration, automated uninstall is no
longer supported.

Remove individual tools with their upstream package manager only when you know
they were installed for this kit.
EOF

exit 1
