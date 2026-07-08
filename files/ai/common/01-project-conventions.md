# Project conventions

## What is APP_NAME?

TODO: Describe what this app does.

## Stack

- Ruby 4.0.5, Rails 8.1, PostgreSQL
- Plain CSS, Hotwire (Turbo + Stimulus), Propshaft + Importmaps (no Webpack)
- Jobs: SolidQueue (not Sidekiq), Action Cable: Solid Cable, Caching: Solid
  Cache (not Redis)
- Minitest (not RSpec), custom `TestData` system (not YAML fixtures)
- Authentication: Rails built-in (email/password, `has_secure_password`)

## CI / quality gates

- **Always run `bin/ci` before committing** — never commit without passing CI
  first. No exceptions.
- If CI fails, fix the issues before committing.
- Do not skip or defer CI to "run later" — the commit should not exist until CI
  passes.

`bin/agent-stop-check` runs on every Claude Code / Codex stop. It runs the
read-only Rails gates: agent-config drift, RuboCop (without `-a`), and
`bin/rails zeitwerk:check`. The full suite (`bin/ci`) — including tests,
brakeman, bundler-audit, importmap audit, migration status — is the pre-commit
gate, not the stop gate.

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

## Code organization [CRITICAL]

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

## Module structure [CRITICAL]

- Keep modules flat (one level: `Inventory::Product`, never deeper)
- Don't create modules for single classes — use root level instead
- Don't split modules speculatively — split when two clusters of classes mostly
  talk to each other, not across
- Expose 1-3 classes as public API per module
- Infrastructure models used everywhere go at root level

## Request-scoped state

`Current` (ActiveSupport::CurrentAttributes) holds the current session/user.
Controllers use an `Authentication` concern with cookie-based sessions.

## UI pattern

Helpers are the primary UI abstraction — not partials or view components.

**ERB tags**: Never use `concat` in views. Use `<%= %>` for helpers that return
HTML and `<% %>` for side-effect calls and control flow.

**CSS**: Use semantic class names and app-level styles in
`app/assets/stylesheets/application.css`. Prefer CSS custom properties for
shared tokens and keep selectors scoped to the component or page they style.

## Code comments

- **Always** comment classes — what it is, how to use it.
- **Always** comment public methods — what it does, not how.
- Comment private methods and lines **only when the logic isn't self-evident**.
- Use plain `#` comments (Rails rdoc style). No ASCII-art banners or section
  dividers.

## Infrastructure mixins

Three sibling modules in `lib/` give classes declarative access to Rails-level
state. Prefer the mixin form over reaching into globals.

- **`Logging`** — class-level loggers. `include Logging` instead of using
  `Rails.logger`. `config.x.logging` is a taglist string
  (e.g. `_all`, `MyClass->debug`, `-NoisyClass`) read from the `LOGGING` env
  var. Loggers go to STDERR.
- **`Credentials`** — `include Credentials::Accessor` and declare named
  accessors with `credentials :aws_key, [:aws, :access_key]`, or call
  `Credentials.read(:aws, :access_key)`. Falls back to env-keyed paths
  (e.g. `development.aws.access_key`) before raising
  `MissingCredentialsError`.
- **`Configuration`** — `include Configuration::Accessor` and declare with
  `config :logging, [:x, :logging]`, or call `Configuration.read(:x, :logging)`.
  Auto-vivified empty `OrderedOptions` reads back as `nil`, not as truthy.

## Project skills

Use the skills under `skills/`:

- `agent-config` — sources for generated agent instructions; how to keep
  `CLAUDE.md` and `AGENTS.md` in sync.

Keep this doc focused on invariants. Procedural, task-triggered guidance lives
in skills.
