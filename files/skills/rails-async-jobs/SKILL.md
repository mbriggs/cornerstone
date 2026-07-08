---
name: rails-async-jobs
description: "Policy for Rails ActiveJob shape — jobs are transport, behavior lives on the model. Use before (1) adding logic to a job's `perform` body beyond a single delegation, (2) making a model method async with a `_later`/`_now` pair, OR (3) adding any AR callback (`before_save`, `after_commit`, etc.) that calls an external service, makes an HTTP request, runs a shell command, or does heavy computation — those external-IO callbacks belong in an async `_later`/`_now` pair instead, otherwise `Model.create!` blocks on the IO and fails when the external service does."
---

# Rails async jobs

ActiveJob classes are shallow. They exist to move work off the request
cycle. The behavior lives on the model; the job calls into it.

## Pattern

A model method that wants to run asynchronously exposes two methods:

- `foo_later` — enqueues the job.
- `foo_now` — does the synchronous work.

The job's `perform` is a single line that calls `foo_now` on the model.

```ruby
module Event::Relaying
  extend ActiveSupport::Concern

  included do
    after_create_commit :relay_later
  end

  def relay_later
    Event::RelayJob.perform_later(self)
  end

  def relay_now
    # the actual relay logic lives here
  end
end

class Event::RelayJob < ApplicationJob
  def perform(event)
    event.relay_now
  end
end
```

## Why this shape

- **Sync-runnable.** `event.relay_now` works in tests, in the console,
  and in synchronous code paths without enqueueing the job. You can test
  the behavior without ActiveJob's test adapter or perform-later
  matchers.
- **One source of truth.** The behavior is on the model, in one place.
  The job is just a delivery mechanism.
- **Easy to retry, replace, or remove.** Swap SolidQueue for Sidekiq, run
  inline in a Rake task, or remove the job entirely — the model code is
  unchanged.

## Naming

Always paired:

- `relay_later` / `relay_now`
- `process_later` / `process_now`
- `notify_later` / `notify_now`

Never put the work on `_later` directly; never put a job-specific name
on the model.

## What goes in perform

One line: call the `_now` method. Everything else — argument
preparation, error handling, retries — happens either on the model or
in `ApplicationJob`.

```ruby
# Avoid
class Event::RelayJob < ApplicationJob
  def perform(event)
    payload = build_payload(event)
    Net::HTTP.post(URI(event.target), payload.to_json)
    event.update!(relayed_at: Time.current)
  end
end

# Prefer
class Event::RelayJob < ApplicationJob
  def perform(event)
    event.relay_now
  end
end
```

## Common temptations to resist

- **"I'll just put the loop in `perform`, it's only three lines."** Three
  lines becomes thirty, and now the only way to test the logic is via
  the job. Put it on the model.
- **"The job needs different behavior in async vs sync."** It does not.
  If `_now` doesn't already work synchronously, the design is wrong;
  fix that instead of branching inside `perform`.
- **"There's no model — it's just a one-off task."** Then write a domain
  object under `app/models/` with the `_later`/`_now` pair on it.
