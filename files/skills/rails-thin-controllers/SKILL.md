---
name: rails-thin-controllers
description: "Policy for Rails controller shape. Use before adding logic to an action longer than ~5 lines or extracting a `FooService` class."
---

# Thin controllers, rich models

Rails controllers should be a thin transport layer. The action receives
a request, calls one method, renders the result. Behavior lives in the
model.

## Plain Active Record is fine

```ruby
class Cards::CommentsController < ApplicationController
  def create
    @comment = @card.comments.create!(comment_params)
  end
end
```

Direct Active Record call. No service object, no extracted helper.

## Intention-revealing model APIs

When behavior is more than `create!`, expose the intent on the model:

```ruby
class Cards::GoldnessesController < ApplicationController
  def create
    @card.gild
  end
end
```

The model decides what `gild` means. The controller only knows the user
asked for it.

## Form-object-ish things stay under app/models/

When you genuinely need an object that orchestrates multiple models or
encapsulates a multi-step operation, write it as a normal domain object:

```ruby
# app/models/signup.rb
Signup.new(email_address: email).create_identity

# app/models/payments/process_refund.rb
Payments::ProcessRefund.new(charge: charge).run
```

Tests mirror under `test/models/` —
`test/models/signup_test.rb`,
`test/models/payments/process_refund_test.rb`.

## Never: app/services/

Do not create `app/services/`. The directory is not part of this Rails
style. A "service object" is just a plain Ruby object that lives under
`app/models/`, where Rails autoloads it from already.

## Why

`app/services/` exists in many Rails codebases because controllers grew
fat and developers reached for an escape valve outside the model. The
model is the right home — it has the data, the validations, and the
lifecycle. Pushing intent-revealing methods onto the model keeps domain
knowledge in one place rather than scattered between
`app/controllers/`, `app/services/`, and `app/models/`.

## Heuristic

- Controller action longer than ~5 lines? → push the body into a model
  method.
- Tempted to write `FooService`? → write `Foo` (or `Foos::DoBar`) under
  `app/models/`.
- Multiple models touched? → still a model. Name it for what it produces
  (`Signup`, `Refund`, `Cancellation`).
