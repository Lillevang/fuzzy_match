# TODO: Write documentation for `FuzzyMatch`

require "levenshtein"

module FuzzyMatch
  VERSION = "0.1.0"

  # TODO: Put your code here

  def self.ratio(s1: String, s2: String) : Float64
  end

  def self.partial_ratio(s1: String, s2: String) : Float64
  end

  def self.token_sort_ratio(s1: String, s2: String) : Float64
  end

  def self.token_set_ratio(s1: String, s2: String) : Float64
  end

  def self.normalize(s : String) : String
  end
  
end
