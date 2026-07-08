---
name: ruby-visibility
description: "Policy for Ruby `private`/`protected` formatting AND semantics. Use before placing a visibility keyword OR when reading code that uses one — verify both the formatting and that the keyword actually has effect. `private` does NOT make `def self.foo` private (singleton methods are unaffected by lexical `private`). Use `class << self; private; ...` or `private_class_method :foo` for class methods."
---

# Ruby visibility modifiers

This style uses 37signals/Basecamp-style formatting for `private` and
`protected`. It departs from the more common Rubocop default.

## Mixed public + private class

`private` sits on its own line with **no blank line below it**, and the
private methods are **indented one extra level** under it.

```ruby
class SomeClass
  def some_method
    # ...
  end

  private
    def some_private_method
      # ...
    end

    def another_private_method
      # ...
    end
end
```

## Module with only private methods

Put `private` at the top with **one blank line after**, and leave the
methods **unindented**.

```ruby
module SomeModule
  private

  def some_private_method
    # ...
  end

  def another_private_method
    # ...
  end
end
```

## What this is not

- **Not** flush-left `private` with a blank line both above and below
  (Rubocop's default `Layout/IndentationConsistency`).
- **Not** `private :method_name` symbol arguments.
- **Not** `private def foo` inline form.

## What `private` doesn't do

`private` has no effect on `def self.foo`. Singleton methods are
unaffected by lexical visibility keywords.

```ruby
# Looks private. Is not.
class Embedder
  private  # <- has no effect on what follows

  def self.load_provider
    # callable as Embedder.load_provider
  end
end
```

Two ways to actually make class methods private:

```ruby
# Option 1: open the singleton class
class Embedder
  class << self
    private

    def load_provider
      # truly private
    end
  end
end

# Option 2: private_class_method after the def
class Embedder
  def self.load_provider
    # ...
  end
  private_class_method :load_provider
end
```

When reading a file, if you see `private` followed by `def self.<name>`
inside a class body, treat it as a visibility lie. Fix it or open a
thread.

## Why

The indent under `private` makes the visibility boundary visually obvious:
methods that sit visually further from the left margin are further from
the public API. The shape of the file tells you what's exposed without
having to scan for keywords.

## Autoformatter notes

If a Rubocop autoformatter reflows `private` sections to flush-left, it
is overriding this style. Either configure `Layout/IndentationConsistency`
to permit the indented form or revert the reformat before committing.
