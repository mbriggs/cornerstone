# HTTP client for the Anthropic Messages API.
#
# Uses Net::HTTP directly — no gem dependency. Handles retries with exponential
# backoff on transient errors (429, 500, 503, 529, network failures).
#
# Models are referenced by symbol (:haiku, :sonnet, :opus) so callers never
# touch version-pinned model ID strings.
#
#   client = AnthropicClient.new
#   client.message(system: "You are helpful.", messages: [...])
#
#   client = AnthropicClient.new(model: :haiku)
#   client.message(system: "Parse this.", messages: [...], max_tokens: 2048)
#
class AnthropicClient
  include Logging
  include Credentials::Accessor
  include Retryable

  credential :api_key, [ :anthropic, :api_key ]

  API_URL = "https://api.anthropic.com/v1/messages"
  API_VERSION = "2023-06-01"
  MAX_RETRIES = 2
  MAX_RETRY_AFTER = 30
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 120

  MODELS = {
    haiku:  "claude-haiku-4-5-20251001",
    sonnet: "claude-sonnet-4-6",
    opus:   "claude-opus-4-6"
  }

  DEFAULT_MODEL = :sonnet
  DEFAULT_MAX_TOKENS = 4096

  # Base error for all API failures. Stores the HTTP status and raw response body.
  class APIError < StandardError
    attr_reader :status, :body, :retry_after

    def initialize(message, status:, body:, retry_after: nil)
      @status = status
      @body = body
      @retry_after = retry_after
      super("#{message} (HTTP #{status})")
    end
  end

  class ConnectionError          < APIError; end # network-level failures
  class BadRequestError          < APIError; end # 400
  class AuthenticationError      < APIError; end # 401
  class RateLimitError           < APIError; end # 429
  class ServerError              < APIError; end # 500
  class ServiceUnavailableError  < APIError; end # 503
  class OverloadedError          < APIError; end # 529

  STATUS_TO_ERROR = {
    400 => BadRequestError,
    401 => AuthenticationError,
    429 => RateLimitError,
    500 => ServerError,
    503 => ServiceUnavailableError,
    529 => OverloadedError
  }

  RETRYABLE = [ ConnectionError, RateLimitError, ServerError, ServiceUnavailableError, OverloadedError ]

  class << self
    def middleware
      @middleware ||= []
    end
  end

  # Mixin that gives any class a private +anthropic+ method returning
  # a lazy-initialized client with default settings.
  #
  # Sets a +class_attribute :anthropic_client+ on the includer so tests can
  # inject a fake without touching the network. When the attribute is nil
  # (the default), a real AnthropicClient is created on first use.
  module Accessor
    def self.included(base)
      base.class_attribute :anthropic_client, instance_writer: false, default: nil
    end

    private

    def anthropic
      @anthropic ||= (self.class.anthropic_client || AnthropicClient.new)
    end
  end

  def initialize(model: DEFAULT_MODEL, max_tokens: DEFAULT_MAX_TOKENS)
    @default_model = model
    @default_max_tokens = max_tokens
  end

  # Sends a message to the Anthropic API and returns the parsed JSON response hash.
  #
  # Message content must pass InputSanitizer.sanitize! — raises UnsanitizedError
  # if dirty text (invisible chars, non-NFC, too long) reaches the API boundary.
  #
  # Pass +track:+ to record token usage via middleware:
  #   client.message(system: "...", messages: [...], track: { trackable: problem, operation: "evaluation" })
  def message(system:, messages:, model: @default_model, max_tokens: @default_max_tokens, read_timeout: READ_TIMEOUT, track: nil, **options)
    messages.each { |msg| InputSanitizer.sanitize!(msg[:content]) }

    model_id = MODELS.fetch(model)
    uri = URI(API_URL)
    body = {
      model: model_id,
      max_tokens: max_tokens,
      system: system,
      messages: messages,
      **options
    }.to_json

    with_retries(*RETRYABLE, max_retries: MAX_RETRIES, max_retry_after: MAX_RETRY_AFTER) do |attempt|
      logger.debug("request model=#{model_id} attempt=#{attempt}")

      response = begin
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: read_timeout) do |http|
          request = Net::HTTP::Post.new(uri)
          request["x-api-key"] = api_key
          request["anthropic-version"] = API_VERSION
          request["content-type"] = "application/json"
          request.body = body
          http.request(request)
        end
      rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
             Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
        raise ConnectionError.new(e.message, status: 0, body: nil)
      end

      status = response.code.to_i
      response_body = response.body
      logger.debug("response status=#{status} model=#{model_id}")

      if status >= 200 && status < 300
        parsed = JSON.parse(response_body)
        run_middleware(parsed, model: model, track: track)
        return parsed
      end

      error_class = STATUS_TO_ERROR.fetch(status, APIError)
      error_message = begin
        JSON.parse(response_body).dig("error", "message") || "API request failed"
      rescue JSON::ParserError
        "API request failed"
      end
      raise error_class.new(error_message, status: status, body: response_body, retry_after: response["retry-after"])
    end
  end

  private

  # Runs registered middleware after a successful API response.
  # Each middleware receives (response, metadata) and is rescued independently.
  def run_middleware(response, model:, track:)
    self.class.middleware.each do |mw|
      mw.call(response, model: model, track: track)
    rescue => e
      logger.error("Middleware #{mw.class} failed: #{e.message}")
    end
  end
end
