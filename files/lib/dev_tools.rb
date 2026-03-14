# Console helpers for development. Include in rails console via:
#   include DevTools
#
# Provides generic utilities for debugging and benchmarking.
# All domain-specific helpers should live elsewhere.
module DevTools
  # Remove Rails backtrace filters so you see full stack traces
  def proper_backtraces!
    Rails.backtrace_cleaner.remove_filters!
    Rails.backtrace_cleaner.remove_silencers!
  end

  # Disable ActiveRecord SQL logging. With a block, re-enables after.
  def disable_rails_logger
    if !ActiveRecord::Base.logger.nil?
      @rails_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = nil
    end

    if block_given?
      yield
      enable_rails_logger
    end
  end

  # Re-enable ActiveRecord SQL logging after disable_rails_logger
  def enable_rails_logger
    return unless !@rails_logger.nil? && ActiveRecord::Base.logger.nil?

    ActiveRecord::Base.logger = @rails_logger
    @rails_logger = nil
    :enabled
  end

  # Simple benchmarking — prints elapsed time for the block
  def time_elapsed
    beginning_time = Time.zone.now
    yield
    end_time = Time.zone.now
    puts "Time elapsed #{(end_time - beginning_time) * 1000} milliseconds"
  end

  # Shortcut for ActiveRecord::Base.transaction
  def transaction(&)
    ActiveRecord::Base.transaction(&)
  end

  # Temporarily raise PG statement_timeout for long-running queries
  def disable_timeout
    ActiveRecord::Base.connection.execute("SET statement_timeout = 3600000")
    yield
  ensure
    ActiveRecord::Base.connection.execute("SET statement_timeout = 5000")
  end
end
