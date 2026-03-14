# Logging is a mixin to enable class based loggers. By default, these loggers will be turned off, and be set to the
# same log level as Rails.logger. To control a logger, you can set config.x.logging in an environment config
# (e.g. config/environments/development.rb). The config is a string in the following format:
#
#   "MyClass->debug,MyOtherClass,-DisabledClass,_all"
#
# In this example:
# - MyClass logger will be set to debug - MyOtherClass logger will be set to whatever Rails.logger is set to
# - DisabledClass will have its logger disabled. This happens via the - prefix
# - all other loggers will be enabled. _all is a magic logger name to allow for this
# - without specifying _all, all unmentioned loggers will be disabled by default
#
# To add this logging system to a class, simply `include Logging`. This will provide a class level as well as an
# instance level logger.
#
# note: Loggers will log to STDERR, the way God intended.
module Logging
  extend ActiveSupport::Concern

  # Set the log tags for the app, this is done in the log_tags initializer
  def self.config=(val)
    @config = Taglist.parse(val)
  end

  def self.config
    @config ||= Taglist.from_config
  end

  class_methods do
    def logger
      if @logger
        return @logger
      end

      config = Logging.config

      dev = config.allow?(name) ? STDERR : File::NULL

      logger = ActiveSupport::TaggedLogging.new(Logger.new(dev))
      logger.level = config.level(name)
      logger.formatter = Rails.logger.formatter

      @logger ||= logger.tagged(name)
    end

    def log_string(string)
      if Rails.env.production?
        string.squish
      else
        string
      end
    end

    def log_hash(hash)
      if Rails.env.production?
        hash.inspect
      else
        JSON.pretty_generate(hash)
      end
    end
  end

  delegate :logger, :log_string, :log_hash,
    to: :class

  class Taglist
    # Parse the taglist config
    #
    def self.parse(taglist_config)
      include = {}
      exclude = {}

      taglist_config.split(",").each do |tag|
        tag = tag.strip

        level = nil
        if tag.include?("->")
          tag, level = tag.split("->")
        end

        if tag.start_with?("-")
          tag = tag[1..]
          exclude[tag] = level
        else
          include[tag] = level
        end
      end

      Taglist.new(include: include, exclude: exclude)
    end

    # A Taglist without inclusions or exclusions
    #
    def self.blank
      @blank ||= new
    end

    # A Taglist built from the rails logging config, if present
    #
    def self.from_config
      config = Rails.application.config.x.logging
      if config.present?
        parse(config)
      else
        blank
      end
    end

    attr_reader :include

    attr_reader :exclude

    def initialize(include: {}, exclude: {})
      @include = include
      @exclude = exclude
    end

    def include?(tag)
      include.key?("_all") || include.key?(tag)
    end

    def exclude?(tag)
      exclude.key?(tag)
    end

    def allow?(*tags)
      tags.any? { |tag| include?(tag) } && !tags.any? { |tag| exclude?(tag) }
    end

    # Configured level for tag, or the Rails.logger level if not present
    def level(tag)
      level_string = include[tag] || exclude[tag] || (include?("_all") ? include["_all"] : nil)
      if level_string
        case level_string.downcase
        when "debug" then Logger::DEBUG
        when "info" then Logger::INFO
        when "warn" then Logger::WARN
        when "error" then Logger::ERROR
        else Rails.logger.level
        end
      else
        Rails.logger.level
      end
    end
  end
end
