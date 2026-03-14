# Cornerstone

A Rails application template for building production apps with opinionated defaults.

## Usage

```bash
rails new myapp --database=postgresql --css=tailwind -m ~/cornerstone/template.rb
cd myapp
bin/setup
bin/dev
```

## What you get

**Authentication** — Invokes the Rails 8 built-in authentication generator (email/password login, password reset), then layers on session expiry, user deactivation, and Bearer token API auth.

**Infrastructure libs** — `Logging` (tagged, filterable via `LOGGING` env var), `Credentials` (typed access to Rails credentials), `Configuration`, `Retryable` (retry with backoff), `AnthropicClient` (Anthropic API via `Net::HTTP`).

**Input sanitization** — `InputSanitizer` strips invisible characters, normalizes Unicode, and truncates. The `Sanitizable` concern applies it before validation; `AnthropicClient` asserts it at the API boundary.

**TestData** — Deterministic test fixtures in Ruby (not YAML). Define fixtures in `lib/test_data/fixtures/`, access them in tests as `users(:alice)`.

**CI script** — `bin/ci` runs linting, security checks, and tests in one command.

**Dev tooling** — `bin/dev` (Procfile-based dev server), `bin/setup` (idempotent setup), `bin/work` (SolidQueue worker), worktree scripts for parallel development, `CLAUDE.md` for Claude Code.

**Security defaults** — Content Security Policy, Permissions Policy, `rack-attack` rate limiting, `filter_parameter_logging`, `bundler-audit` config.

## Stack

- Ruby, Rails 8, PostgreSQL
- Tailwind CSS, Hotwire (Turbo + Stimulus), Propshaft + Importmaps
- SolidQueue, Solid Cable, Solid Cache (no Redis)
- Minitest, Bullet (N+1 detection), RuboCop, Brakeman

## Gems added

| Category | Gems |
|---|---|
| UI | heroicons, pagy, hotwire_combobox, commonmarker |
| Infrastructure | rack-attack, mission_control-jobs |
| Dev/test | bullet |

## What the template does

1. Adds gems (before bundle)
2. Runs `generate "authentication"` for base auth
3. Copies customized models, concerns, configs, and migrations from `files/`
4. Configures `application.rb` (autoload paths, logging, Turbo preload fix)
5. Configures dev/test environments (SolidQueue, Bullet)
6. Creates initial git commit

## Customization

Everything the template copies lives in `files/`. Edit those files to change what gets generated. The template itself (`template.rb`) controls gem additions, generator invocations, and config patching.

## After generating

```bash
bin/rails credentials:edit    # Add anthropic.api_key
```

Update `CLAUDE.md` with your project description and add fixtures in `lib/test_data/fixtures/`.
