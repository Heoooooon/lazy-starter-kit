#requires -Version 5.1

Write-Error @'
lazy-starter-kit no longer provides an automatic uninstaller.

Automatic removal was retired because the kit cannot reliably distinguish tools
it installed from tools that already existed on a user's machine. Removing by
package ID or path could delete pre-existing developer tools or user data.

Nothing was changed or removed.

To remove individual tools, use each tool's official uninstall instructions and
review your PowerShell profile manually.
'@

exit 2
