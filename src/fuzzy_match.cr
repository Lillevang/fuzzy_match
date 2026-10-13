require "./fuzzy_match/normalize"
require "./fuzzy_match/scorers"
require "./fuzzy_match/extract"

# Fuzzy string matching for Crystal.
#
# Every scorer compares two strings and returns a similarity between `0.0`
# (nothing in common) and `100.0` (identical). The scorers follow the
# definitions used by Python's `fuzzywuzzy` and `rapidfuzz`, so scores carry
# over if you already have thresholds tuned for those libraries.
#
# ```
# FuzzyMatch.ratio("this is a test", "this is a test!")                           # => 96.55
# FuzzyMatch.partial_ratio("world", "hello world")                                # => 100.0
# FuzzyMatch.token_sort_ratio("fuzzy wuzzy was a bear", "wuzzy fuzzy was a bear") # => 100.0
# FuzzyMatch.token_set_ratio("fuzzy was a bear", "fuzzy fuzzy was a bear")        # => 100.0
#
# FuzzyMatch.extract_one("new york jets", teams).try &.choice # => "New York Jets"
# ```
#
# See `FuzzyMatch.ratio`, `FuzzyMatch.partial_ratio`, `FuzzyMatch.token_sort_ratio`,
# `FuzzyMatch.token_set_ratio`, `FuzzyMatch.weighted_ratio` and `FuzzyMatch.extract`.
module FuzzyMatch
  VERSION = "0.1.1"
end
