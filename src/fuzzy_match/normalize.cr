module FuzzyMatch
  # Lowercases *s*, replaces every run of non-alphanumeric characters with a
  # single space and trims the ends. This is what the token scorers and
  # `weighted_ratio` do to their input before comparing.
  #
  # ```
  # FuzzyMatch.normalize("  Hello, World! Øl & 123 ") # => "hello world øl 123"
  # ```
  #
  # Alphanumeric is decided per Unicode character, so letters outside ASCII
  # (æ, ø, å, ü, ...) are kept and only punctuation and symbols become spaces.
  def self.normalize(s : String) : String
    String.build(s.bytesize) do |io|
      pending_space = false
      s.each_char do |char|
        if char.alphanumeric?
          io << ' ' if pending_space
          io << char.downcase
          pending_space = false
        elsif !io.empty?
          pending_space = true
        end
      end
    end
  end

  # Splits *s* on whitespace into its tokens.
  protected def self.tokens(s : String) : Array(String)
    s.split
  end
end
