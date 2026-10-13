module FuzzyMatch
  # Plain similarity of the two strings as a whole.
  #
  # Defined as `2 * LCS / (|a| + |b|) * 100`, where LCS is the length of the
  # longest common subsequence. Equivalently, it is the normalized *indel*
  # distance: how many insertions and deletions turn one string into the
  # other, relative to the combined length. Two empty strings score `100.0`.
  #
  # ```
  # FuzzyMatch.ratio("this is a test", "this is a test!")   # => 96.55
  # FuzzyMatch.ratio("kitten", "sitting")                   # => 61.54
  # FuzzyMatch.ratio("Crystal", "crystal")                  # => 85.71
  # FuzzyMatch.ratio("Crystal", "crystal", normalize: true) # => 100.0
  # ```
  def self.ratio(a : String, b : String, normalize : Bool = false) : Float64
    a, b = self.normalize(a), self.normalize(b) if normalize
    similarity(a.chars, b.chars)
  end

  # Best `ratio` of the shorter string against any window of the longer one.
  #
  # Useful when one string is a fragment of the other: a surname against a
  # full name, a word against a sentence. The windows include ones that hang
  # over the start or end of the longer string, so a partially matching
  # prefix or suffix still counts.
  #
  # ```
  # FuzzyMatch.partial_ratio("world", "hello world")               # => 100.0
  # FuzzyMatch.partial_ratio("Lillevang", "Lillevang Consult ApS") # => 100.0
  # FuzzyMatch.partial_ratio("kitten", "sitting")                  # => 66.67
  # ```
  def self.partial_ratio(a : String, b : String, normalize : Bool = false) : Float64
    a, b = self.normalize(a), self.normalize(b) if normalize
    short, long = a.chars, b.chars
    short, long = long, short if short.size > long.size
    return similarity(short, long) if short.empty?

    n, m = short.size, long.size
    best = 0.0
    # Windows that overhang the start, every full-width window, and windows
    # that overhang the end, in that order. Stop at the first perfect score.
    (1...n).each do |len|
      best = Math.max(best, similarity(short, long, 0, len))
      return best if best == 100.0
    end
    (0..m - n).each do |start|
      best = Math.max(best, similarity(short, long, start, n))
      return best if best == 100.0
    end
    (m - n + 1...m).each do |start|
      best = Math.max(best, similarity(short, long, start, m - start))
      return best if best == 100.0
    end
    best
  end

  # `ratio` of the two strings with their words sorted alphabetically, so
  # word order no longer matters.
  #
  # ```
  # FuzzyMatch.token_sort_ratio("fuzzy wuzzy was a bear", "wuzzy fuzzy was a bear") # => 100.0
  # FuzzyMatch.token_sort_ratio("New York Mets vs Atlanta Braves",
  #   "Atlanta Braves vs New York Mets") # => 100.0
  # ```
  def self.token_sort_ratio(a : String, b : String, normalize : Bool = true) : Float64
    a, b = self.normalize(a), self.normalize(b) if normalize
    ratio(sorted_tokens(a), sorted_tokens(b))
  end

  # Like `token_sort_ratio`, but compares with `partial_ratio` so a shorter
  # string whose words all appear in the longer one scores `100.0`.
  def self.partial_token_sort_ratio(a : String, b : String, normalize : Bool = true) : Float64
    a, b = self.normalize(a), self.normalize(b) if normalize
    partial_ratio(sorted_tokens(a), sorted_tokens(b))
  end

  # Similarity based on the *sets* of words in each string.
  #
  # The words both strings share are split off into an intersection, and the
  # leftovers of each string are compared with and without that common
  # prefix. Duplicated words and word order are ignored, and a string whose
  # words are all contained in the other scores `100.0`. This is the scorer
  # for "is this the same thing, written differently?".
  #
  # ```
  # FuzzyMatch.token_set_ratio("fuzzy was a bear", "fuzzy fuzzy was a bear") # => 100.0
  # FuzzyMatch.token_set_ratio("mariners vs angels",
  #   "los angeles angels of anaheim at seattle mariners") # => 90.91
  # ```
  #
  # Returns `0.0` when either string has no words at all.
  def self.token_set_ratio(a : String, b : String, normalize : Bool = true) : Float64
    a, b = self.normalize(a), self.normalize(b) if normalize
    tokens_a, tokens_b = tokens(a).uniq!.sort!, tokens(b).uniq!.sort!
    return 0.0 if tokens_a.empty? || tokens_b.empty?

    common = tokens_a & tokens_b
    only_a = (tokens_a - common).join(' ')
    only_b = (tokens_b - common).join(' ')
    # One string's words are all in the other.
    return 100.0 if !common.empty? && (only_a.empty? || only_b.empty?)

    sect = common.join(' ')
    sect_len = sect.size
    # Length of "<sect> <only_x>", without the space when sect is empty.
    sect_a_len = sect_len + (sect_len > 0 ? 1 : 0) + only_a.size
    sect_b_len = sect_len + (sect_len > 0 ? 1 : 0) + only_b.size

    # ratio("<sect> <only_a>", "<sect> <only_b>"): the shared prefix lines up
    # exactly, so only the leftovers need an alignment.
    distance = sect_a_len + sect_b_len - 2 * lcs_length(only_a.chars, only_b.chars) - 2 * sect_len
    result = 100.0 - 100.0 * distance / (sect_a_len + sect_b_len)
    return result if sect_len == 0

    # ratio("<sect>", "<sect> <only_x>"): everything after sect is an insertion.
    sect_a = 100.0 - 100.0 * (1 + only_a.size) / (sect_len + sect_a_len)
    sect_b = 100.0 - 100.0 * (1 + only_b.size) / (sect_len + sect_b_len)
    {result, sect_a, sect_b}.max
  end

  # Like `token_set_ratio`, but compares the leftovers with `partial_ratio`.
  # Any word in common scores `100.0`.
  def self.partial_token_set_ratio(a : String, b : String, normalize : Bool = true) : Float64
    a, b = self.normalize(a), self.normalize(b) if normalize
    tokens_a, tokens_b = tokens(a).uniq!.sort!, tokens(b).uniq!.sort!
    return 0.0 if tokens_a.empty? || tokens_b.empty?

    common = tokens_a & tokens_b
    return 100.0 unless common.empty?
    partial_ratio(tokens_a.join(' '), tokens_b.join(' '))
  end

  # The all-rounder: picks the scorer that fits the two strings.
  #
  # Strings of similar length are compared with `ratio` and the token
  # scorers. When one string is much longer than the other, the partial
  # scorers are used instead, and their scores are scaled down so that an
  # exact match still ranks above a fragment match. The input is normalized
  # first. This is the default scorer for `extract`.
  #
  # ```
  # FuzzyMatch.weighted_ratio("New York Jets", "new york jets") # => 100.0
  # FuzzyMatch.weighted_ratio("Jets", "New York Jets")          # => 90.0
  # FuzzyMatch.weighted_ratio("kitten", "sitting")              # => 61.54
  # ```
  #
  # Returns `0.0` when either string is empty after normalization.
  def self.weighted_ratio(a : String, b : String, normalize : Bool = true) : Float64
    a, b = self.normalize(a), self.normalize(b) if normalize
    return 0.0 if a.empty? || b.empty?

    unbase_scale = 0.95
    len_a, len_b = a.size, b.size
    length_ratio = Math.max(len_a, len_b).to_f / Math.min(len_a, len_b)

    best = ratio(a, b)
    if length_ratio < 1.5
      token = Math.max(token_sort_ratio(a, b, normalize: false), token_set_ratio(a, b, normalize: false))
      return Math.max(best, token * unbase_scale)
    end

    partial_scale = length_ratio < 8 ? 0.9 : 0.6
    best = Math.max(best, partial_ratio(a, b) * partial_scale)
    partial_token = Math.max(
      partial_token_sort_ratio(a, b, normalize: false),
      partial_token_set_ratio(a, b, normalize: false)
    )
    Math.max(best, partial_token * unbase_scale * partial_scale)
  end

  private def self.sorted_tokens(s : String) : String
    tokens(s).sort!.join(' ')
  end

  # Similarity of *a* against the window of *b* starting at *start* with
  # *len* characters, as a percentage.
  private def self.similarity(a : Array(Char), b : Array(Char), start : Int32 = 0, len : Int32 = b.size) : Float64
    total = a.size + len
    return 100.0 if total == 0
    200.0 * lcs_length(a, b, start, len) / total
  end

  # Length of the longest common subsequence of *a* and `b[start, len]`,
  # using the classic two-row dynamic programming table.
  private def self.lcs_length(a : Array(Char), b : Array(Char), start : Int32 = 0, len : Int32 = b.size) : Int32
    return 0 if a.empty? || len == 0
    prev = Array(Int32).new(len + 1, 0)
    curr = Array(Int32).new(len + 1, 0)
    a.each do |char|
      len.times do |j|
        curr[j + 1] = char == b[start + j] ? prev[j] + 1 : Math.max(prev[j + 1], curr[j])
      end
      prev, curr = curr, prev
    end
    prev[len]
  end
end
