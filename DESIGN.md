# CMORE Ready Design System

## 0. Research Log

- **Existing surface audit:** `gui/macos/main.swift`, the signed `v0.10.2` app, `README.md`, and `docs/images/*` were reviewed. The installer is functional but visually flat: one undifferentiated stack, no brand mark, weak hierarchy, and no persistent application icon. The existing README hero and social card use two unrelated visual languages.
- **Embedded references:** Apple was selected as the Layer B reference because the product is a native macOS utility. The redesign ruleset is the Layer A reference. We keep native controls, system typography, keyboard behavior, semantic colors, and restrained material depth rather than imitating a web dashboard.
- **Lazyweb:** searches for `developer tool onboarding desktop`, `macOS setup assistant installer`, and `AI developer environment desktop` returned 18 shipped-product references. TestFlight, Termius, and Apple Support were selected for closer inspection. Useful shared grammar: a calm single-purpose canvas, one dominant action, compact contextual controls, an explicit status region, and high-density technical output visually separated from setup choices.
- **Concept drafts:** image-generation tooling is unavailable in this workspace. The icon and social card therefore use deterministic vector geometry defined below. Two external visual-design reviewers were attempted but unavailable because the configured organization rejects OAuth; this is compensated for by fresh rendered evidence and the required independent Visual QA gate.

## 1. Product and Principles

**Promise:** one trusted action turns a new computer into a ready development environment.

**Product name:** `CMORE Ready`

**Brand line:** `새 컴퓨터, 개발 준비 끝.` / `Your dev machine, ready to build.`

**Open-source relationship:** the commercial-facing product is `CMORE Ready by
CMORE`; the underlying open-source project remains `lazy-starter-kit` and is
credited as `Powered by lazy-starter-kit`.

1. **Native before novel.** Controls behave like macOS controls and remain legible in light, dark, increased-contrast, and reduced-transparency modes.
2. **One decision at a time.** Profile and preview choices lead to one primary installation action.
3. **Technical, not intimidating.** Logs are real and selectable, but visually contained below a plain-language status.
4. **Trust is visible.** Dry-run, Developer ID signing, and non-destructive defaults appear as product qualities, not footnotes.
5. **No decorative motion.** State changes use color, icon, and copy; no ambient animation.

## 2. Brand Geometry

The mark is a rounded graphite tile containing a mint command chevron and a blue starting line:

- Outer tile: continuous rounded rectangle, 22% corner radius.
- Command chevron: two mint strokes meeting at the horizontal centerline.
- Starting line: one cobalt horizontal stroke aligned with the chevron tip.
- Three small source nodes: macOS, Linux, and Windows converge visually into the command mark at large sizes; omit them below 32 px.
- Outer tile bleed margin: 7% to preserve the native macOS app-icon silhouette.
- Glyph safe area: at least 16% inside the tile. No letters or platform logos inside the icon.
- Source nodes are omitted below 32 px; small sizes retain only the command chevron and starting line.

This geometry is shared by the Finder/Dock icon, the installer header, README hero, and social preview.

## 3. Color Tokens

All application colors must resolve through semantic/dynamic `NSColor` values.

| Token | Light intent | Dark intent | Use |
|---|---|---|---|
| `canvas` | system window background | system window background | window |
| `surface` | white at 78% | white at 7% | setup card |
| `surfaceStrong` | `#F4F7FA` | `#111821` | log panel |
| `line` | black at 10% | white at 12% | separators |
| `text` | label | label | primary copy |
| `muted` | secondary label | secondary label | supporting copy |
| `mint` | `#00A985` | `#56E6BF` | brand and success |
| `cobalt` | `#2867E8` | `#6B9CFF` | primary action |
| `statusBlue` | `#0047B8` | `#6B9CFF` | running status |
| `statusGreen` | `#006B52` | `#56E6BF` | success status |
| `statusRed` | `#B52317` | `#FF8A80` | failure status |
| `warning` | system orange | system orange | non-fatal attention |
| `failure` | system red | system red | errors |

Never use pure black for log text. The selectable multi-line log field uses the native dynamic `labelColor`.

## 4. Typography

- Product eyebrow: 11 pt semibold, tracked uppercase, secondary color.
- Screen title: 28 pt bold, tight native tracking.
- Screen subtitle: 14 pt regular, secondary color, maximum two lines.
- Section title: 13 pt semibold.
- Control and status copy: 13 pt medium/regular.
- Log: 12 pt SF Mono, 1.35 line height equivalent, selectable.
- Korean copy must not orphan particles or split short predicate phrases. Width constraints must preserve `새 컴퓨터, 개발 준비 끝.` as a balanced phrase.

## 5. Spacing and Layout

- Window content: 760 × 800 pt, minimum window frame 700 × 742 pt.
- Outer inset: 28 pt horizontal, 24 pt vertical.
- Major vertical rhythm: 20 pt.
- Header: 64 pt icon beside title/subtitle; 16 pt gap.
- Setup surface: 18 pt inset, 14 pt corner radius.
- Control row: profile selector expands; secondary preview action remains intrinsic; primary button remains at least 132 × 36 pt.
- Status strip: 36 pt minimum, icon + status + trust note + update link.
- Log surface: fills remaining height, 250 pt or taller at the standard window size, and may compress to 170 pt at the minimum window size; 14 pt text inset.

The content uses constraints only. Resizing must expand the log surface without stretching controls.

## 6. Components and States

### Brand mark

Custom vector `NSImage`; rendered at runtime and packaged as `AppIcon.icns`. It must remain identifiable at 16, 32, 128, and 512 px.

### Profile selector

Native `NSPopUpButton` with `slider.horizontal.3` context icon. The initial selection is `AI 코딩 시작 — 추천` (`ai`): Git, Node.js LTS/npm, Claude Code, Codex, safety hooks, and only the PATH setup needed in a new terminal.

Explicit advanced presets retain their existing identifiers and payloads:

- 개발 도구 추천 (`recommended`) — `prereqs,brew,runtimes,shell,git,agents`; broad developer tools with Claude Code and Codex, without Docker
- 전체 설치 — complete environment (unchanged, including Docker)
- 최소 설치 — essentials only
- 회사 PC용 — no Docker

The profile is a starting point. A `사용자 지정` state appears when users change the runtime, Docker, or AI-agent component checkboxes. Changing from AI to an advanced/custom selection must not retain the AI-only package restriction.

### Component selection and permissions

- Required AI tools are described together without asking beginners to select their dependencies. Advanced profiles retain their core-tool dependencies.
- Language runtimes, Docker, and AI agents can be included independently.
- AI agents require Node.js/npm. The AI profile does not select Python, Go, Rust, Docker, shell cosmetics, or the broader convenience-tool bundle.
- The exact tools are visible before execution and `cmore.dev` provides the plain-language guide.
- “Administrator” means a macOS administrator account allowed to approve software installation. The app never asks for, stores, echoes, or pipes a password.
- Standard users stop before payload execution and are told to ask the Mac administrator.
- First-time Xcode Command Line Tools or Homebrew setup is handed to a mode-0700 Terminal command carrying the selected installer steps. Homebrew remains under the logged-in user and owns any native `sudo` prompt.
- Ready prerequisites remain in the GUI. Every terminal state restores the controls so the app can be used again.

### Preview control

A secondary native Preview button is separate from the primary Install action. Packaged preview works without installing prerequisites or creating a practice folder, and never unlocks first-run controls.

### Primary action

Prominent native push button with `arrow.down.circle.fill`. Copy progresses:

1. `설치 시작`
2. In-progress status with cancellation
3. Verified first-run actions, or a concrete action-needed state

First-time prerequisite setup continues in Terminal and offers `설치 결과 확인` as a read-only continuation rather than requiring another install. Standard-user and recoverable failures offer a concrete retry or permission instruction.

Default-button keyboard behavior remains Return.

An active run adds a contextual secondary action (`미리보기 취소` or
`설치 취소`). The close control is disabled
while work is active; choosing Quit cancels the complete installer process tree,
waits for cleanup, and only then terminates the app. Cancellation restores every
setup control and reports a neutral mode-specific cancellation state.

The AI profile requires successful executable checks before enabling first-run controls. A process exit alone is insufficient. Preview, failure, cancellation, partial setup, and a Terminal handoff awaiting verification do not claim readiness. AI diagnosis checks the intended AI scope rather than marking deliberately excluded developer tools missing; existing explicit advanced profiles remain available.

Before installation, explain that provider accounts and eligible service access or API billing are separate. After verified installation, expose a Claude Code / Codex choice, a new empty practice-folder launch action, and a starter-prompt copy action. Handle spaces, Korean characters, and apostrophes in paths without overwriting existing files. Launch only after a user action; login, trust approval, and prompt submission remain manual. Readiness never claims provider authentication or successful prompt execution.

Automatic uninstall remains retired. Do not add removal buttons, automatic cleanup of installed tools or user data, or a legacy management/removal tab as part of onboarding.

### Version and updates

The status strip shows the real release version and a `새 버전 확인 ↗` link to
GitHub Releases. Development builds are labeled `개발 빌드`. Release apps bundle
their reviewed bootstrap and pin both `STARTER_KIT_BRANCH` and
`STARTER_KIT_COMMIT` to their own immutable release; they never download
mutable `main` before those pins are active.

### Status strip

Uses `circle.fill`, `checkmark.circle.fill`, `xmark.circle.fill`, or `arrow.down.circle` according to state. Status text and icon both change; color is never the only signal.

### Log surface

Header uses `terminal.fill`, title `실행 로그`, and a trailing `⌘A로 선택 · 복사 가능` hint. A separate native label presents the plain-language empty state and hides when execution begins. During execution, output is appended to a selectable multi-line `NSTextField` with dynamic label color and a monospaced system font.

Detailed logs are expandable. The current stage and actionable completion state remain visible when logs are collapsed. Preserve native keyboard navigation, semantic colors, and readable Korean labels at the minimum supported window size on both desktop platforms.

## 7. Accessibility and Interaction

- Native keyboard navigation and Return activation remain intact.
- Every icon has adjacent visible text or an accessibility label.
- Minimum control height: 28 pt; primary action: 36 pt.
- Status never relies on color alone.
- Dynamic system colors support light/dark and increased contrast.
- The layout tolerates 125% text scaling without clipping its Korean labels.
- The app icon and social card preserve sufficient contrast without glow-dependent legibility.

## 8. Brand Surfaces and Handoff

- README hero: 1600 × 900 SVG, editorial product overview with the shared mark and one clear command line.
- GitHub social preview: 1280 × 640, safe text region centered within 1120 × 520, no small dependency lists.
- Repository description: concise English for GitHub search and link cards.
- Release app: `CFBundleIconFile=AppIcon`, icon resources present, Hardened Runtime and notarization preserved.

**Accepted debt:** Windows retains its current native dialog in this increment; the requested redesign follows the active macOS GUI release path. The shared brand assets and copy remain platform-neutral for a later Windows-native surface.

## 9. Website Surface

The `cmore.dev` landing page is a product introduction, not an exhaustive
technical manual. Its decision path is: understand the promise, see the real
setup flow, verify trust, inspect what is installed, then start for free.

### Audience and jobs

- **New developer:** wants a working machine without learning every package
  manager first.
- **Experienced developer:** wants to inspect the command, preserve existing
  settings, and verify the open-source implementation.
- **Team lead:** wants a repeatable, auditable baseline across operating
  systems.

### Web tokens

The website uses the existing graphite, mint, and cobalt system:

- `webCanvas`: `#070B12`
- `webCanvasRaised`: `#0D141E`
- `webSurface`: `#111B27`
- `webSurfaceStrong`: `#172433`
- `webLine`: `rgba(255, 255, 255, 0.12)`
- `webText`: `#F4F7FB`
- `webMuted`: `#A8B4C3`
- `webMint`: `#56E6BF`
- `webCobalt`: `#6B9CFF`
- `webWarning`: `#F4C76B`

The display face remains the system sans stack with tight tracking; commands
and technical labels use the system mono stack. Web spacing follows a 4 px
base, with 8, 12, 16, 24, 32, 48, 72, and 96 px steps. Content width is capped
at 1180 px.

### Web primitives

- **Top bar:** compact CMORE Ready wordmark, anchor navigation, and one GitHub
  action. It stays readable without becoming a floating pill.
- **Primary action:** cobalt filled button with visible hover, pressed, and
  focus-visible states.
- **Secondary action:** text link or quiet outlined button; never a competing
  second filled button.
- **Setup window:** live DOM composition showing profile selection, progress,
  and repository-backed example status. It is the dimensional hero object and
  must never be replaced by a screenshot or imply that the static demo is a
  live installer session.
- **Proof rail:** unboxed, bordered facts for platform coverage, preservation,
  and CI verification.
- **Platform actions:** separate macOS and Windows GUI ZIP downloads and a Linux
  setup guide. Show the published version and source/release distinction before
  the download choices, with a separate release-notes link. When the release
  predates recommended setup, prominently direct users to the current-source
  guide instead of presenting the old ZIP as the new configuration. Links never
  execute installer code directly.
- **Editorial section:** left-aligned heading paired with asymmetric supporting
  content; avoid generic three-card feature rows.

### Responsive behavior

- At 1280 px, the hero is a 5/7 split with copy on the left and the setup window
  on the right.
- At 768 px, the hero stacks and the setup window remains fully legible.
- At 375 px, navigation collapses to the wordmark and GitHub action; platform
  download actions stack without changing page width.
- Korean display copy uses balanced wrapping and must not leave particles or a
  final syllable orphaned.

### Accessibility and trust

- Include a skip link, semantic landmarks, visible focus rings, and a
  reduced-motion path.
- Vendor logos are not used. Platform and tool names appear as text so
  compatibility never implies endorsement.
- Claims must map to shipped repository behavior. Paid support, automatic
  updates, or subscriptions are not advertised until those products exist.
- Footer links identify the MIT source, security policy, license, and
  third-party relationship.

**Accepted website debt:** checkout, waitlist collection, privacy policy, terms,
and refund pages remain out of scope until a commercial transaction or personal
data collection is introduced. Existing open-source release artifacts and the
installer UI retain the `Lazy Starter Kit` name until a separately verified
release rebrand; the landing identifies that relationship as `Powered by
lazy-starter-kit` rather than presenting the current artifacts as newly named.
