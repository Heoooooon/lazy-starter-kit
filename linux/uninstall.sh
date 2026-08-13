#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'EOF'
lazy-starter-kit no longer provides an automatic uninstaller.

Automatic removal was retired because the kit cannot reliably distinguish tools
it installed from tools that already existed on a user's machine. Removing by
package name or path could delete pre-existing developer tools or user data.

Nothing was changed or removed.

To remove individual tools, use each tool's official uninstall instructions and
review your shell configuration manually.
EOF

exit 2
