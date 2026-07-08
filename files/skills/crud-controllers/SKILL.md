---
name: crud-controllers
description: "Policy for Rails routes/controllers — model endpoints as CRUD on resources. Use before adding any HTTP route whose URL path contains a verb. There is almost always a resource hiding inside."
---

# CRUD controllers

Model web endpoints as CRUD on resources. The seven standard actions —
`index`, `show`, `new`, `create`, `edit`, `update`, `destroy` — should
cover every endpoint. When behavior does not fit, find the resource
hiding behind the verb and introduce it.

## Avoid: custom verbs

```ruby
resources :cards do
  member do
    post :close
    post :reopen
  end
end
```

`close` and `reopen` look like verbs, but they are state changes — and
a state has a name.

## Prefer: a new resource

```ruby
resources :cards do
  resource :closure
end
```

`Cards::ClosuresController#create` closes a card.
`Cards::ClosuresController#destroy` reopens it. The route, the
controller, and the tests all read cleanly:

```
POST    /cards/:card_id/closure   → closes the card
DELETE  /cards/:card_id/closure   → reopens the card
```

## How to find the resource

Ask: what is the *thing* that comes into existence when this action runs?

- `archive` → an `Archival`.
- `publish` → a `Publication`.
- `cancel` → a `Cancellation`.
- `approve` → an `Approval`.
- `subscribe` → a `Subscription`.
- `gild` → a `Goldness` (or `Gilding`).

The verb is the action; the noun is the resource. Once you have the noun,
the rest of the design follows: a controller per resource, a model per
resource, tests mirroring each.

## Why

Resources give you:

- A natural place to store data about the action (when it happened, who
  did it, what it cost).
- A namespace for the controller and its tests
  (`Cards::ClosuresController`, `test/controllers/cards/closures_controller_test.rb`).
- Composability: nested resources, member/collection routes, and form
  helpers all assume a resource shape.

Custom verbs give you none of that — you get one method on the original
controller and a flat namespace.

## When custom actions are unavoidable

Custom actions are acceptable when the behavior genuinely is not a
resource — e.g. a webhook receiver that does not own state, or an
endpoint that returns ad-hoc reporting data. These are rare; default to
finding the resource first.
