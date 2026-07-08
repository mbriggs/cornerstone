---
name: conditional-returns
description: "Policy for guard clauses vs. expanded if/else in Ruby. Use before writing a `return unless`/`return if` near the top of a method; expanded if/else beats guards when both branches are ordinary flow."
---

# Conditional returns

Prefer expanded `if`/`else` when both branches are part of the method's
ordinary flow. Reserve guard clauses for early aborts at the top of
non-trivial methods.

## Avoid: guard clause masquerading as flow

```ruby
# Avoid
def todos_for_new_group
  ids = params.require(:todolist)[:todo_ids]
  return [] unless ids

  @bucket.recordings.todos.find(ids.split(","))
end
```

The `return [] unless ids` is not really a guard — it is one of two
ordinary outcomes. The reader has to mentally invert the negative
condition and remember that the rest of the method is the "yes" branch.

## Prefer: expanded conditional

```ruby
# Prefer
def todos_for_new_group
  if ids = params.require(:todolist)[:todo_ids]
    @bucket.recordings.todos.find(ids.split(","))
  else
    []
  end
end
```

Both branches are visible. The reader sees `if ids → find them, else → []`
in one glance.

## When guard clauses are right

Guards work when the early return is genuinely a precondition check,
the return is at the very beginning of the method, and the main body is
non-trivial.

```ruby
def after_recorded_as_commit(recording)
  return if recording.parent.was_created?

  if recording.was_created?
    broadcast_new_column(recording)
  else
    broadcast_column_change(recording)
  end
end
```

Here the `return if` aborts processing entirely when a precondition fails;
the rest of the method is real work. That is the shape a guard clause is
for.

## Heuristic

- Two ordinary outcomes? → `if`/`else`.
- Skip everything when a precondition fails? → guard clause.
- Method body is one or two lines? → almost always `if`/`else`.

## Why

The "always use guard clauses to reduce nesting" advice optimizes for
shallow indentation. That trade is worth it when the early return is
truly an exit. It is not worth it when both paths are part of the
method's job — the reader pays in inverted logic and missing structural
cues.
