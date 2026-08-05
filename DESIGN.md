# Lazy Starter Kit Design System

## 0. Research Log

- **Existing surface audit:** `gui/macos/main.swift`, the signed `v0.10.2` app, `README.md`, and `docs/images/*` were reviewed. The installer is functional but visually flat: one undifferentiated stack, no brand mark, weak hierarchy, and no persistent application icon. The existing README hero and social card use two unrelated visual languages.
- **Embedded references:** Apple was selected as the Layer B reference because the product is a native macOS utility. The redesign ruleset is the Layer A reference. We keep native controls, system typography, keyboard behavior, semantic colors, and restrained material depth rather than imitating a web dashboard.
- **Lazyweb:** searches for `developer tool onboarding desktop`, `macOS setup assistant installer`, and `AI developer environment desktop` returned 18 shipped-product references. TestFlight, Termius, and Apple Support were selected for closer inspection. Useful shared grammar: a calm single-purpose canvas, one dominant action, compact contextual controls, an explicit status region, and high-density technical output visually separated from setup choices.
- **Concept drafts:** image-generation tooling is unavailable in this workspace. The icon and social card therefore use deterministic vector geometry defined below. Two external visual-design reviewers were attempted but unavailable because the configured organization rejects OAuth; this is compensated for by fresh rendered evidence and the required independent Visual QA gate.

## 1. Product and Principles

**Promise:** one trusted action turns a new computer into a ready development environment.

**Brand line:** `한 줄이면, 바로 시작.` / `One line. Ready to build.`

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
- Korean copy must not orphan particles or split short predicate phrases. Width constraints must preserve `한 줄이면, 바로 시작.` on one line.

## 5. Spacing and Layout

- Window content: 760 × 680 pt, minimum window frame 700 × 660 pt.
- Outer inset: 28 pt horizontal, 24 pt vertical.
- Major vertical rhythm: 20 pt.
- Header: 64 pt icon beside title/subtitle; 16 pt gap.
- Setup surface: 18 pt inset, 14 pt corner radius.
- Control row: profile selector expands; preview checkbox remains intrinsic; primary button remains at least 132 × 36 pt.
- Status strip: 36 pt minimum, icon + status + trust note.
- Log surface: fills remaining height, 300 pt or taller at the standard window size, and may compress to 170 pt at the minimum window size; 14 pt text inset.

The content uses constraints only. Resizing must expand the log surface without stretching controls.

## 6. Components and States

### Brand mark

Custom vector `NSImage`; rendered at runtime and packaged as `AppIcon.icns`. It must remain identifiable at 16, 32, 128, and 512 px.

### Profile selector

Native `NSPopUpButton` with `slider.horizontal.3` context icon and three localized choices:

- 전체 설치 — complete environment
- 최소 설치 — essentials only
- 회사 PC용 — no Docker

### Preview control

Native checkbox, on by default. Supporting trust copy explains that no changes are made.

### Primary action

Prominent native push button with `arrow.down.circle.fill`. Copy progresses:

1. `미리보기 시작`
2. `실제 설치 시작`
3. `다시 실행`

Default-button keyboard behavior remains Return.

### Status strip

Uses `circle.fill`, `checkmark.circle.fill`, `xmark.circle.fill`, or `arrow.down.circle` according to state. Status text and icon both change; color is never the only signal.

### Log surface

Header uses `terminal.fill`, title `실행 로그`, and a trailing `⌘A로 선택 · 복사 가능` hint. A separate native label presents the plain-language empty state and hides when execution begins. During execution, output is appended to a selectable multi-line `NSTextField` with dynamic label color and a monospaced system font.

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
