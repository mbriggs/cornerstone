# Drop-in fake for AnthropicClient that acts as both a configurable stub
# and a request spy. Use via AnthropicTestHelper#with_fake_anthropic.
#
#   # Model test
#   test "evaluates Problem via LLM" do
#     fake = with_fake_anthropic(Problem::Evaluation)
#     fake.respond_with('{"evaluation_dimensions": [], "feedback": "Good.", "summary": "A feature."}')
#
#     result = Problem::Evaluation.new(problem.current_markdown).call
#     assert result[:feedback]
#   end
#
#   # Error scenario
#   test "handles API error" do
#     fake = with_fake_anthropic(Problem::Evaluation)
#     fake.respond_with(AnthropicClient::APIError.new("overloaded", status: 529, body: nil))
#
#     assert_raises(AnthropicClient::APIError) { Problem::Evaluation.new("# Problem").call }
#   end
#
class FakeAnthropicClient
  attr_reader :requests

  def initialize(**) # accepts model:/max_tokens: like the real client
    @responses = []
    @requests = []
    @call_index = 0
    @mutex = Mutex.new
  end

  # Queue one or more canned responses. Each argument can be:
  #   - String   → wrapped into an Anthropic-shaped response hash
  #   - Hash     → returned as-is
  #   - Exception (or subclass instance) → raised on the matching call
  def respond_with(*responses)
    responses.each { |r| @responses << r }
  end

  # Duck-types AnthropicClient#message. Records every call and returns
  # the next queued response (or a default empty response).
  # Validates message content is sanitized, matching real client behavior.
  # Mirrors real client's track: behavior — creates ApiUsage records.
  def message(track: nil, **kwargs)
    (kwargs[:messages] || []).each { |msg| InputSanitizer.sanitize!(msg[:content]) }
    @mutex.synchronize do
      @requests << kwargs.merge(track: track)
      response = @responses[@call_index]
      @call_index += 1

      parsed = case response
      when Exception then raise response
      when Hash      then response
      when String    then wrap_text(response)
      when nil       then wrap_text("")
      end

      run_middleware(parsed, model: kwargs[:model], track: track)
      parsed
    end
  end

  def last_request
    @requests.last
  end

  private

  # Delegates to the shared AnthropicClient middleware stack so the test
  # fake exercises the same recording path as the real client.
  def run_middleware(response, model:, track:)
    AnthropicClient.middleware.each do |mw|
      mw.call(response, model: model || :sonnet, track: track)
    rescue => e
      # Mirror real client: don't blow up on middleware failures
    end
  end

  def wrap_text(text)
    {
      "id" => "msg_fake_#{@call_index - 1}",
      "type" => "message",
      "role" => "assistant",
      "content" => [ { "type" => "text", "text" => text } ],
      "model" => "claude-sonnet-4-5-20250929",
      "stop_reason" => "end_turn",
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }
  end
end

# Test helper that injects a FakeAnthropicClient into any class that
# includes AnthropicClient::Accessor. Automatically cleans up in teardown.
#
#   fake = with_fake_anthropic(Problem::Evaluation)
#   fake.respond_with("hello")
#
module AnthropicTestHelper
  extend ActiveSupport::Concern

  included do
    teardown :reset_anthropic_fakes
  end

  # Injects a new FakeAnthropicClient into +klass+ and returns it.
  # The override is automatically cleared in teardown.
  def with_fake_anthropic(klass)
    fake = FakeAnthropicClient.new
    klass.anthropic_client = fake
    (@_anthropic_fakes ||= []) << klass
    fake
  end

  private

  def reset_anthropic_fakes
    if @_anthropic_fakes
      @_anthropic_fakes.each { |klass| klass.anthropic_client = nil }
      @_anthropic_fakes = nil
    end
  end
end
