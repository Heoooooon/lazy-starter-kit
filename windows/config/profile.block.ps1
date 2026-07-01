# managed by lazy-starter-kit -- edits between the markers are overwritten on re-run.

# mise: node / python / go version manager
if (Get-Command mise -ErrorAction SilentlyContinue) {
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

# bat: nicer cat
if (Get-Command bat -ErrorAction SilentlyContinue) {
  function cat { bat --paging=never @args }
}

# starship prompt -- keep LAST so it owns the prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (& starship init powershell)
}
