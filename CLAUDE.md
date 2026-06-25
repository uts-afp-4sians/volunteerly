# CLAUDE.md

Guidance for working in this repo. Keep it short — document conventions that
aren't obvious from the code, not things the code already shows.

## Layout
- `volunteerly/` + `volunteerly.xcodeproj` — SwiftUI iOS app (the mobile client).
- `api/` — FastAPI backend (Python, uv + Turso/SQLite), `mise` tasks.
- `api/openapi.json` — the API contract, the single source of truth for codegen.

## iOS build / run
- The machine's `xcode-select` points at CommandLineTools, so prefix Xcode tools
  with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Build: `xcodebuild -project volunteerly.xcodeproj -scheme volunteerly -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- The target uses **file-system-synchronized groups** — new files under
  `volunteerly/` are auto-included; no `.pbxproj` edits needed to add sources.
- The app starts at a splash that only routes to the main UI when a session
  exists. To reach it in the simulator, inject one at launch:
  `xcrun simctl launch booted com.4sians.volunteerly -auth_token mock`.

## Design system
**Always use the design tokens — never hardcode hex or `.system(size:)`.**
- Colours live in `Assets.xcassets` and are exposed as auto-generated symbols:
  `Color.brand/.brandLight/.brandDark`, `.secondaryBlue/.secondaryBlueLight/.secondaryBlueDark`,
  `.accentYellow/.accentYellowLight/.accentYellowDark`, `.pageBackground`, `.textPrimary`,
  `.fieldError`. `AccentColor` (`Color.accent`) is the brand green global tint.
- Typography + text-style helpers are in `volunteerly/Shared/DesignSystem/Typography.swift`:
  `Font.pageTitle/.subheading/.sectionHeader/.bodyStrong/.bodyText/.buttonLabel/.labelItalic`,
  plus `Text.requiredFieldStyle()` and `.linkStyle()`.
- **Naming gotcha (don't "fix"):** the blue and yellow families are named
  `SecondaryBlue*` / `AccentYellow*`, not `Secondary*` / `Accent*`, on purpose —
  the short names collide with the built-in `Color.secondary` and the `AccentColor`
  symbol and reintroduce build warnings.

## API client codegen
- `mise gen:api` regenerates everything: `api gen:openapi` (FastAPI → `api/openapi.json`)
  then `gen:api:mobile` (swift-openapi-generator → `volunteerly/Core/Networking/Generated/`).
- Generated `Client.swift`/`Types.swift` are committed — **regenerate, don't hand-edit.**
  `openapi-generator-config.yaml` filters by tag to keep output small; widen it as new
  screens consume new resources.
- **The spec is OpenAPI 3.0, not 3.1 — do not revert.** `api/scripts/gen_openapi.py`
  down-converts FastAPI's 3.1 output to 3.0.3 because swift-openapi-generator drops
  3.1's `anyOf:[X,{type:null}]` nullable fields; 3.0's `nullable:true` round-trips correctly.
- `API.makeClient()` (`APIClient.swift`) builds the generated client over URLSession; it
  coexists with the existing `HTTPClient`/`MockHTTPClient` mock layer (no full migration yet).

## Naming
- The forum feature is `Forum*` in iOS code (`ForumPost`, `ForumComment`) even though the
  ERD calls it `BOARD_*`. Keep "Forum" in iOS and API code/UI; the JSON keys already match.
- **Swift file names must not contain `+`.** Use a descriptive suffix instead:
  `PostProgramViewSections.swift` not `PostProgramView+Sections.swift`.

## R2 object storage
- Bucket: `volunteerly-media` (Cloudflare R2, APAC; account id comes from `R2_ACCOUNT_ID` env)
- Public base URL: `https://pub-33ddcaa8fd164c628cabe79a0c47c85c.r2.dev`
- Object key schema: `{kind}/{user_id}/{uuid4().hex}.webp`
  - `profile_image/{user_id}/{32-char-hex}.webp`
  - `program_banner/{user_id}/{program_id|0}/{32-char-hex}.webp`
- Filenames use `uuid4().hex` (32 hex chars, no hyphens) — URL-safe with no special characters.
- ContentType is locked to `image/webp`; iOS converts before upload via `CGImageDestination`.
- Presign TTL: 300 s. Max upload size enforced client-side: 5 MB.

<!-- OMA:START — managed by oh-my-agent. Do not edit this block manually. -->

# oh-my-agent

## Architecture

- **SSOT**: `.agents/` directory (do not modify directly)
- **Response language**: Follows `language` in `.agents/oma-config.yaml`
- **Skills**: `.agents/skills/` (domain specialists)
- **Workflows**: `.agents/workflows/` (multi-step orchestration)
- **Subagents**: Same-vendor native dispatch via Claude Code Agent tool with `.claude/agents/{name}.md`; cross-vendor fallback via `oma agent:spawn`

## Per-Agent Dispatch

1. Resolve `target_vendor_for_agent` from `.agents/oma-config.yaml`.
2. If `target_vendor_for_agent === current_runtime_vendor`, use the runtime's native subagent path.
3. If vendors differ, or native subagents are unavailable, use `oma agent:spawn` for that agent only.

## Code Search

Prefer **serena MCP** tools over native find/grep when locating code — they are symbol-aware and faster on large repos. Fall back to native Read / Glob / Grep only when serena is unavailable or for plain file content reads.

| Task | Preferred tool |
|------|----------------|
| Locate a symbol definition (class / function / variable) | `find_symbol` |
| Find references / callers of a symbol | `find_referencing_symbols` |
| Outline a file's top-level symbols | `get_symbols_overview` |
| Pattern or regex search across the codebase | `search_for_pattern` |
| Find a file by name | `find_file` |
| List directory contents | `list_dir` |

## Workflows

Execute by naming the workflow in your prompt. Keywords are auto-detected via hooks.

| Workflow | File | Description |
|----------|------|-------------|
| orchestrate | `orchestrate.md` | Parallel subagents + Review Loop |
| work | `work.md` | Step-by-step with remediation loop |
| ultrawork | `ultrawork.md` | 5-Phase Gate Loop (11 reviews) |
| ralph | `ralph.md` | Persistent loop wrapping ultrawork with an independent judge |
| plan | `plan.md` | PM task breakdown |
| brainstorm | `brainstorm.md` | Design-first ideation |
| architecture | `architecture.md` | Architecture diagnosis, comparison, ADR |
| design | `design.md` | Design system + DESIGN.md with anti-pattern enforcement |
| review | `review.md` | QA audit |
| debug | `debug.md` | Root cause + minimal fix |
| deepsec | `deepsec.md` | Drive `oma-deepsec` end-to-end (setup / scan / pr-review / matchers / triage) |
| scm | `scm.md` | SCM + Git operations + Conventional Commits |
| docs | `docs.md` | Documentation drift verify + sync |
| recap | `recap.md` | Daily / period AI conversation recap |
| deepinit | `deepinit.md` | Project harness init (AGENTS.md / ARCHITECTURE.md / docs/) |
| convert | `convert.md` | File format conversion by category: documents→Markdown (oma-pdf/oma-hwp), image/video/audio transcode (ffmpeg) |
| video | `video.md` | Brief → script → assets → render-spec → Remotion (oma-video) |
| schedule | `schedule.md` | Register & manage time-based agent jobs via `oma schedule:*` |

(`tools` and `stack-set` are slash-invoked utilities, and `schedule` is a slash-invoked workflow (`oma schedule:*` time-based jobs); all are intentionally excluded from keyword detection.)

To execute: read and follow `.agents/workflows/{name}.md` step by step.

## Auto-Detection

Hooks: `UserPromptSubmit` (keyword detection), `PreToolUse`, `Stop` (persistent mode)
Keywords defined in `.agents/hooks/core/triggers.json` (multi-language).
Persistent workflows (orchestrate, ultrawork, work, ralph) block termination until complete.
Deactivate: say "workflow done".

## Rules

1. **Do not modify `.agents/` files** (SSOT protection).
2. Workflows execute via keyword detection or explicit naming, never self-initiated.
3. Response language follows `.agents/oma-config.yaml`

## Project Rules

Read the relevant file from `.agents/rules/` when working on matching code.

| Rule | File | Scope |
|------|------|-------|
| backend | `.agents/rules/backend.md` | on request |
| commit | `.agents/rules/commit.md` | on request |
| database | `.agents/rules/database.md` | **/*.{sql,prisma} |
| debug | `.agents/rules/debug.md` | on request |
| design | `.agents/rules/design.md` | on request |
| dev-workflow | `.agents/rules/dev-workflow.md` | on request |
| frontend | `.agents/rules/frontend.md` | **/*.{tsx,jsx,css,scss} |
| i18n-arb | `.agents/rules/i18n-arb.md` | **/*.arb |
| i18n-guide | `.agents/rules/i18n-guide.md` | always |
| infrastructure | `.agents/rules/infrastructure.md` | **/*.{tf,tfvars,hcl} |
| market | `.agents/rules/market.md` | on request |
| mobile | `.agents/rules/mobile.md` | **/*.{dart,swift,kt} |
| quality | `.agents/rules/quality.md` | on request |

<!-- OMA:END -->
