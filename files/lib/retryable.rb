# Mixin providing retry-with-exponential-backoff for transient failures.
#
# Same usage pattern as Logging and Credentials — include the module, then call
# `with_retries` around any operation that may fail transiently.
#
#   include Retryable
#
#   with_retries(RateLimitError, ServerError, max_retries: 2) do |attempt|
#     http_call(...)
#   end
#
# Honors `retry_after` on exceptions that carry it (e.g. API rate-limit errors).
module Retryable
  extend ActiveSupport::Concern

  included do
    include Logging unless ancestors.include?(Logging)
  end

  private

  def with_retries(*error_classes, max_retries: 2, max_retry_after: nil, sleep_fn: method(:sleep))
    attempt = 0
    begin
      yield attempt
    rescue *error_classes => e
      raise if attempt >= max_retries
      delay = 2**attempt + rand(0.0..1.0)
      ra = e.try(:retry_after)&.to_f
      if ra
        ra = [ ra, max_retry_after ].min if max_retry_after
        delay = [ delay, ra ].max
      end
      logger.warn { "retrying in #{delay.round(1)}s (#{e.class}: #{e.message}) attempt=#{attempt + 1}" }
      sleep_fn.call(delay)
      attempt += 1
      retry
    end
  end
end
