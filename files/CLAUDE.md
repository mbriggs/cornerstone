# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What is APP_NAME?

TODO: Describe what this app does.

## Commands

```bash
bin/dev                                    # Start dev server (localhost:3000)
bin/setup                                  # Install deps, prepare DB
bin/setup --reset                          # Reset DB and re-setup
bin/ci                                     # Full CI: lint, security, tests
bin/rails test                             # All unit/integration tests
bin/rails test test/controllers/           # Test a directory
bin/rails test test/controllers/foo_controller_test.rb      # Single file
bin/rails test test/controllers/foo_controller_test.rb:25   # Single test by line
bin/rails test:system                      # System tests (browser, slow)
bin/rubocop -a                             # Lint + auto-fix
bin/brakeman --quiet --no-pager            # Security static analysis
```

## Workflow [CRITICAL]

- **Always run `bin/ci` before committing** — never commit without passing CI
  first. No exceptions.
- If CI fails, fix the issues before committing.
- Do not skip or defer CI to "run later" — the commit should not exist until CI
  passes.

## Tech Stack

- Ruby 4.0.1, Rails 8.1, PostgreSQL
- Tailwind CSS, Hotwire (Turbo + Stimulus), Propshaft + Importmaps (no Webpack)
- Jobs: SolidQueue (not Sidekiq), Action Cable: Solid Cable,
  Caching: Solid Cache (not Redis)
- Anthropic API via `AnthropicClient` (custom `Net::HTTP` client, no gem).
  Markdown rendering: `commonmarker` (with HTML sanitization)
- Minitest (not RSpec), custom `TestData` system (not YAML fixtures)
- Authentication: Rails built-in (email/password, `has_secure_password`)

## Architecture

### Code organization [CRITICAL]

- Domain logic lives in `app/models/` — **never** create `app/services/`
  - Service objects: `app/models/payments/process_refund.rb`
  - Tests mirror: `test/models/payments/process_refund_test.rb`
- Controllers stay at top level by default — use namespaces for purpose (API,
  admin) or resource nesting, not model domain modules
- Jobs stay at top level — they coordinate across modules
- View helpers in `app/helpers/` drive most UI rendering
- Stimulus controllers in `app/javascript/controllers/` for client-side behavior
- Infrastructure modules (`Logging`, `Credentials`, `Configuration`,
  `Retryable`) live in `lib/`

### Module structure [CRITICAL]

- Keep modules flat (one level: `Inventory::Product`, never deeper)
- Don't create modules for single classes — use root level instead
- Don't split modules speculatively — split when two clusters of classes mostly
  talk to each other, not across
- Expose 1-3 classes as public API per module
- Infrastructure models used everywhere go at root level

### Input sanitization

Two methods, two boundaries:

- `InputSanitizer.sanitize(text)` — active policy: strips invisible chars,
  normalizes to NFC, truncates. Called by the `Sanitizable` concern before
  validation so all persisted text is clean regardless of entry point.
- `InputSanitizer.sanitize!(text)` — assertion: raises `UnsanitizedError` if
  dirty text reaches the API boundary. Called by `AnthropicClient` on user-role
  message content.

### Request-scoped state

`Current` (ActiveSupport::CurrentAttributes) holds the current session/user.
Controllers use an `Authentication` concern with cookie-based sessions.

### UI pattern

Helpers are the primary UI abstraction — not partials or view components.

**ERB tags**: Never use `concat` in views. Use `<%= %>` for helpers that return
HTML and `<% %>` for side-effect calls and control flow.

**Container queries**: `<main>` has `@container`. Inside content use `@sm:`,
`@md:`, `@lg:`, `@xl:` (not `sm:`, `md:`) — they measure content width, not
viewport.

## Code Comments

- **Always** comment classes — what it is, how to use it.
- **Always** comment public methods — what it does, not how.
- Comment private methods and lines **only when the logic isn't self-evident**.
- Use plain `#` comments (Rails rdoc style). No ASCII-art banners or section
  dividers.

## Logging

Use `include Logging` mixin (from `lib/logging.rb`), not `Rails.logger`.
`config.x.logging` controls which loggers are active (taglist string, default
`_all` via `LOGGING` env var). Narrow with e.g.
`LOGGING="AnthropicClient->debug"`.

## Learnings
