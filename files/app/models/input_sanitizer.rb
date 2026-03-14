# Preprocesses user-supplied text for the Anthropic API.
#
# Two methods, two boundaries:
#
#   InputSanitizer.sanitize(text)   — active policy: strips invisible chars,
#                                     normalizes to NFC, truncates. Use at write
#                                     time (Sanitizable concern) to clean text
#                                     before persistence.
#
#   InputSanitizer.sanitize!(text)  — assertion: raises UnsanitizedError if the
#                                     text contains invisible chars, non-NFC, or
#                                     exceeds max length. Use at the API boundary
#                                     (AnthropicClient) to verify that text was
#                                     sanitized on write.
#
# Detection patterns are a monitoring aid, not a gate — pattern-matching alone
# cannot prevent prompt injection (OWASP LLM01:2025).
module InputSanitizer
  include Logging

  # Raised by sanitize! when text contains unsanitized content.
  class UnsanitizedError < StandardError; end

  # Zero-width and bidirectional override characters that have no place in
  # Problem text but can hide instructions from human reviewers.
  INVISIBLE_CHARS = /[\u200B\u200C\u200D\uFEFF\u200E\u200F\u202A-\u202E\uFFF9-\uFFFB\uFFFC]/

  # Patterns indicating overt injection attempts. Used for logging, not blocking.
  SUSPICIOUS_PATTERNS = [
    /ignore\s+(all\s+)?(previous|prior|above)\s+(instructions|prompts|rules)/i,
    /you\s+are\s+now\s+(a|an|in)\b/i,
    /\bsystem\s*:\s*you\s+are\b/i,
    /\bnew\s+instructions?\s*:/i,
    /\b(disregard|forget|override)\s+(your|the|all)\s+(instructions|rules|prompt)/i,
    /<\/?system>/i,
    /\[\s*INST\s*\]/i
  ]

  MAX_LENGTH = 100_000 # ~25k tokens at 4 chars/token

  module_function

  # Sanitizes text: strips invisible chars, normalizes to NFC, truncates.
  # Returns a plain String. Use for all user-supplied text before persistence.
  def sanitize(text, max_length: MAX_LENGTH)
    return "" if text.blank?

    result = text.to_s.dup
    result.gsub!(INVISIBLE_CHARS, "")
    result = result.unicode_normalize(:nfc)
    result = result.truncate(max_length, omission: "") if result.length > max_length

    log_suspicious_patterns(result)

    result
  end

  # Asserts that text is already clean. Raises UnsanitizedError on the first
  # violation found. Returns the text unchanged if clean.
  #
  # Checks (in order): invisible chars, non-NFC normalization, length overflow.
  def sanitize!(text, max_length: MAX_LENGTH)
    return text if text.blank?

    str = text.to_s

    if str.match?(INVISIBLE_CHARS)
      raise UnsanitizedError, "Text contains invisible Unicode characters (zero-width, BiDi overrides). Sanitize before persisting."
    end

    unless str.unicode_normalized?(:nfc)
      raise UnsanitizedError, "Text is not NFC-normalized. Sanitize before persisting."
    end

    if str.length > max_length
      raise UnsanitizedError, "Text exceeds max length of #{max_length} characters (got #{str.length}). Sanitize before persisting."
    end

    text
  end

  def log_suspicious_patterns(text)
    SUSPICIOUS_PATTERNS.each do |pattern|
      if text.match?(pattern)
        logger.warn("Suspicious input pattern: #{pattern.source}")
      end
    end
  end
end
