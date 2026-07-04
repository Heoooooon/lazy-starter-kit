# managed by lazy-starter-kit -- edits between the markers are overwritten on re-run.

# mise: node / python / go version manager
if (Get-Command mise -ErrorAction SilentlyContinue) {
  # On Windows PowerShell 5.1 mise warns that its chpwd hook needs PS 7+ on
  # every new shell -- scary noise for beginners, and the hook (auto version
  # switch on cd) is a nice-to-have, not required. Suppress just that warning.
  if ($PSVersionTable.PSVersion.Major -lt 7) { $env:MISE_PWSH_CHPWD_WARNING = '0' }
  (& mise activate pwsh) -join "`n" | Invoke-Expression
}

# bun: global packages (e.g. gjc / gajae-code) live in ~/.bun/bin
$env:BUN_INSTALL = Join-Path $env:USERPROFILE '.bun'
if (Test-Path (Join-Path $env:BUN_INSTALL 'bin')) {
  $env:Path = (Join-Path $env:BUN_INSTALL 'bin') + ';' + $env:Path
}

# rust (rustup / cargo)
if (Test-Path (Join-Path $env:USERPROFILE '.cargo\bin')) {
  $env:Path = (Join-Path $env:USERPROFILE '.cargo\bin') + ';' + $env:Path
}

# Claude Code (claude.exe) installs to ~/.local/bin. The installer also adds a
# User-scope PATH entry of its own, so this may be redundant -- but it's a cheap,
# idempotent guarantee that `claude` resolves in every new shell.
if (Test-Path (Join-Path $env:USERPROFILE '.local\bin')) {
  $env:Path = (Join-Path $env:USERPROFILE '.local\bin') + ';' + $env:Path
}

# PSReadLine: zsh-autosuggestions-style inline prediction + completion menu.
# (Syntax highlighting as you type is built into PSReadLine -- no config needed.)
if (Get-Module -ListAvailable -Name PSReadLine) {
  Import-Module PSReadLine -ErrorAction SilentlyContinue
  # command-based predictions (needs PSReadLine 2.2+); enables HistoryAndPlugin
  Import-Module CompletionPredictor -ErrorAction SilentlyContinue
  # inline gray suggestion from history (+ plugins) -- the zsh-autosuggestions feel
  try { Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction Stop }
  catch { try { Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue } catch {} }
  # dropdown list of suggestions (PSReadLine 2.2+); harmless if unsupported
  try { Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue } catch {}
  try { Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue } catch {}
  # Tab -> completion menu (like zsh completions)
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
  # Up/Down = search history by what you've already typed (zsh history-substring-search)
  Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward -ErrorAction SilentlyContinue
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward  -ErrorAction SilentlyContinue
}

# PSFzf: fuzzy finder keybindings (Ctrl-T files, Ctrl-R history) when installed
if (Get-Module -ListAvailable -Name PSFzf) {
  Import-Module PSFzf -ErrorAction SilentlyContinue
  try { Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue } catch {}
}

# bat: nicer cat. 'cat' is a built-in ALIAS for Get-Content and PowerShell resolves
# Alias > Function, so a plain `function cat` would be dead code -- remove the alias
# first. The process/end blocks let it work both with file args (`cat file`) and as
# a pipeline target (`git diff | cat`): piped input is collected and forwarded.
if (Get-Command bat -ErrorAction SilentlyContinue) {
  Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
  function cat {
    begin { $piped = @() }
    # A process block runs ONCE with $_ = $null when the function is called
    # standalone (`cat file`), so filter nulls or that phantom item would make us
    # pipe a blank line to bat instead of passing the file argument through.
    process { if ($null -ne $_) { $piped += $_ } }
    end {
      if ($piped.Count -gt 0) { $piped | bat --paging=never @args }
      else { bat --paging=never @args }
    }
  }
}

# starship prompt -- keep LAST so it owns the prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (& starship init powershell)
}
