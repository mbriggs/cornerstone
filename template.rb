# Cornerstone — Rails Application Template
#
# Usage:
#   rails new myapp --database=postgresql -m ~/cornerstone/template.rb

# =============================================================================
# Phase 1: Gem additions (before bundle)
# =============================================================================

# Infrastructure
gem "rack-attack"
gem "mission_control-jobs"

# Development & test
gem_group :development, :test do
  gem "bullet"
end

# =============================================================================
# Phase 2: after_bundle
# =============================================================================

after_bundle do
  # --- Set source paths to files/ directory ---
  source_paths.unshift(File.join(__dir__, "files"))

  # --- Run the built-in authentication generator ---
  # Creates User, Session, Current models, sessions/passwords controllers,
  # views, mailer, routes, migrations, and enables bcrypt.
  generate "authentication"
  remove_file "test/fixtures/users.yml"

  # The auth generator doesn't add a root route, but the generated
  # SessionsController and Authentication concern both redirect to it.
  route 'root "sessions#new"'

  # --- Copy all files from files/ into the app ---

  # lib/
  %w[
    lib/logging.rb
    lib/credentials.rb
    lib/configuration.rb
    lib/retryable.rb
    lib/dev_tools.rb
    lib/test_data.rb
    lib/test_data/fixture.rb
    lib/test_data/helpers.rb
    lib/test_data/fixtures/users.rb
  ].each { |f| copy_file f, force: true }

  # app/models/
  %w[
    app/models/user.rb
    app/models/session.rb
    app/models/api_token.rb
    app/models/current.rb
  ].each { |f| copy_file f, force: true }

  # app/controllers/concerns/
  %w[
    app/controllers/concerns/authentication.rb
    app/controllers/concerns/api_authentication.rb
  ].each { |f| copy_file f, force: true }

  # test/
  %w[
    test/test_helper.rb
    test/test_helpers/session_test_helper.rb
    test/test_helpers/api_test_helper.rb
    test/support/html_test_helper.rb
    test/models/user_test.rb
    test/models/session_test.rb
    test/models/api_token_test.rb
    test/system/.keep
  ].each { |f| copy_file f, force: true }

  # ai/ agent-instruction sources (CLAUDE.md and AGENTS.md are generated)
  %w[
    ai/common/01-project-conventions.md
    ai/rules/agent-config.md
  ].each { |f| copy_file f, force: true }

  # skills/ — project-owned skills
  %w[
    skills/agent-config/SKILL.md
    skills/conditional-returns/SKILL.md
    skills/crud-controllers/SKILL.md
    skills/rails-async-jobs/SKILL.md
    skills/rails-thin-controllers/SKILL.md
    skills/ruby-visibility/SKILL.md
  ].each { |f| copy_file f, force: true }

  # config/
  %w[
    config/database.yml
    config/cable.yml
    config/queue.yml
    config/cache.yml
    config/ci.rb
    config/bundler-audit.yml
    config/initializers/content_security_policy.rb
    config/initializers/permissions_policy.rb
    config/initializers/filter_parameter_logging.rb
    config/initializers/inflections.rb
    config/initializers/rack_attack.rb
  ].each { |f| copy_file f, force: true }

  # bin/
  %w[
    bin/ci
    bin/dev
    bin/setup
    bin/workers
    bin/loc
    bin/worktree-setup
    bin/worktree-teardown
    bin/port-allocate
    bin/port-deallocate
    bin/mcp-setup
    bin/sync-agent-config
    bin/link-skills
    bin/agent-stop-check
  ].each { |f| copy_file f, force: true }

  # dotfiles & root files
  %w[
    .claude/settings.json
    .claude/settings.local.json
    .claude/hooks/post-edit.sh
    .codex/hooks.json
    .config/wt.toml
    .env
    .env.local.template
    .mcp.json
    .mise.toml
    .rubocop.yml
    Procfile.dev
  ].each { |f| copy_file f, force: true }

  # --- Migrations (copy with sequential timestamps) ---
  # The authentication generator already created users and sessions tables.
  # These migrations add our extra columns and the api_tokens table.

  base_time = Time.now.utc + 60
  migrations = {
    "db/migrate/00000001_add_fields_to_users.rb"       => "add_fields_to_users.rb",
    "db/migrate/00000002_add_expires_at_to_sessions.rb" => "add_expires_at_to_sessions.rb",
    "db/migrate/00000003_create_api_tokens.rb"          => "create_api_tokens.rb"
  }
  migrations.each_with_index do |(src, name), i|
    ts = (base_time + i).strftime("%Y%m%d%H%M%S")
    copy_file src, "db/migrate/#{ts}_#{name}", force: true
  end

  # --- Modify config/application.rb ---

  # Replace autoload_lib line
  gsub_file "config/application.rb",
    /config\.autoload_lib\(.*\)/,
    'config.autoload_lib(ignore: %w[assets tasks test_data])'

  # Add logging config, preload_links_header, and console DevTools after autoload_lib
  inject_into_file "config/application.rb",
    after: /config\.autoload_lib\(.*\)\n/ do
    <<-RUBY

    config.x.logging = ENV.fetch("LOGGING", "_all")

    # Disable automatic Link preload headers — Turbo handles asset loading
    # and the preload hints go unused, causing browser warnings.
    config.action_view.preload_links_header = false

    console do
      TOPLEVEL_BINDING.eval("include DevTools")
    end
    RUBY
  end

  # --- Development environment config ---

  environment nil, env: "development" do
    <<~RUBY
      # SolidQueue for background jobs in development
      config.active_job.queue_adapter = :solid_queue

      # Bullet: detect N+1 queries
      config.after_initialize do
        Bullet.enable = true
        Bullet.rails_logger = true
        Bullet.add_footer = true
      end
    RUBY
  end

  # --- Test environment config ---

  environment nil, env: "test" do
    <<~RUBY
      # Bullet: raise on N+1 queries in tests
      config.after_initialize do
        Bullet.enable = true
        Bullet.raise = true
      end
    RUBY
  end

  # --- Make bin scripts executable ---

  %w[
    bin/ci bin/dev bin/setup bin/workers bin/loc
    bin/worktree-setup bin/worktree-teardown
    bin/port-allocate bin/port-deallocate bin/mcp-setup
    bin/sync-agent-config bin/link-skills bin/agent-stop-check
    .claude/hooks/post-edit.sh
  ].each { |f| chmod f, 0o755 }

  # --- Replace APP_NAME placeholders ---
  # Only static config files get replaced. Bin scripts derive the app name
  # at runtime from the Rails module name in config/application.rb.
  # CLAUDE.md/AGENTS.md are generated from ai/common, so APP_NAME is
  # substituted in the source file before sync runs.

  %w[
    config/database.yml
    .mcp.json
    ai/common/01-project-conventions.md
  ].each do |f|
    gsub_file f, "APP_NAME", app_name
  end

  # __APP_UPPER__ is the uppercase env-var prefix (e.g. MYAPP_USER_EMAIL).
  gsub_file ".env.local.template", "__APP_UPPER__", app_name.upcase

  # --- Generate CLAUDE.md / AGENTS.md / .claude/rules from ai/ sources ---

  run "bin/sync-agent-config"

  # --- Allow committing .env and .env.local.template ---
  # Rails' default .gitignore has `/.env*` which would block both. Punch
  # holes so the shared defaults and template are committable, while
  # .env.local stays ignored.

  gsub_file ".gitignore", /^\/\.env\*\s*$/, <<~GITIGNORE.chomp
    /.env*
    !/.env
    !/.env.local.template
  GITIGNORE

  append_to_file ".gitignore", <<~GITIGNORE

  # Worktree-specific env (port, API tokens)
  worktree.env
  GITIGNORE

  # --- Print next-steps instructions ---

  say ""
  say "=== Cornerstone setup complete! ===", :green
  say ""
  say "Next steps:"
  say "  1. cd #{app_name}"
  say "  2. bin/setup"
  say "  3. bin/dev"
  say ""
  say "  - Add credentials: bin/rails credentials:edit"
  say "  - Add test fixtures in lib/test_data/fixtures/"
  say "  - Describe the project: edit ai/common/01-project-conventions.md,"
  say "    then run bin/sync-agent-config (regenerates CLAUDE.md + AGENTS.md)"
  say "  - Authenticate GitHub CLI: gh auth login"
  say ""

  # --- Git init + initial commit ---

  git :init unless File.exist?(".git")
  git add: "."
  git commit: "-m 'Initial commit via Cornerstone template'"

end
