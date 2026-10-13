module FuzzyMatch
  # The scorers `extract` and `extract_one` can be asked for by name.
  enum Scorer
    Ratio
    PartialRatio
    TokenSortRatio
    TokenSetRatio
    PartialTokenSortRatio
    PartialTokenSetRatio
    WeightedRatio

    # Scores *a* against *b* with this scorer, using its default normalization.
    def call(a : String, b : String) : Float64
      case self
      in .ratio?                    then FuzzyMatch.ratio(a, b)
      in .partial_ratio?            then FuzzyMatch.partial_ratio(a, b)
      in .token_sort_ratio?         then FuzzyMatch.token_sort_ratio(a, b)
      in .token_set_ratio?          then FuzzyMatch.token_set_ratio(a, b)
      in .partial_token_sort_ratio? then FuzzyMatch.partial_token_sort_ratio(a, b)
      in .partial_token_set_ratio?  then FuzzyMatch.partial_token_set_ratio(a, b)
      in .weighted_ratio?           then FuzzyMatch.weighted_ratio(a, b)
      end
    end
  end

  # One result of `extract`: the matching *choice*, its *score* and its
  # *index* in the list of choices it came from.
  record Match, choice : String, score : Float64, index : Int32

  # Scores *query* against every string in *choices* and returns the matches
  # sorted best first. Ties keep the order of *choices*.
  #
  # - *scorer* picks the scoring function; `weighted_ratio` by default.
  # - *limit* caps the number of matches returned.
  # - *cutoff* drops every match scoring below it.
  #
  # ```
  # teams = ["Atlanta Falcons", "New York Jets", "New York Giants", "Dallas Cowboys"]
  #
  # FuzzyMatch.extract("new york jets", teams, limit: 2)
  # # => [Match(@choice="New York Jets", @score=100.0, @index=1),
  # #     Match(@choice="New York Giants", @score=78.57, @index=2)]
  #
  # FuzzyMatch.extract("cowboys", teams, scorer: :ratio, cutoff: 90.0) # => []
  # ```
  def self.extract(query : String, choices : Enumerable(String), scorer : Scorer = :weighted_ratio,
                   limit : Int32? = nil, cutoff : Float64 = 0.0) : Array(Match)
    extract(query, choices, limit: limit, cutoff: cutoff) { |a, b| scorer.call(a, b) }
  end

  # Same as `extract`, but scores each pair with the block instead of a
  # built-in scorer.
  #
  # ```
  # FuzzyMatch.extract("crystal", langs) { |a, b| FuzzyMatch.ratio(a, b, normalize: true) }
  # ```
  def self.extract(query : String, choices : Enumerable(String), limit : Int32? = nil, cutoff : Float64 = 0.0,
                   & : String, String -> Float64) : Array(Match)
    matches = [] of Match
    choices.each_with_index do |choice, index|
      score = yield query, choice
      matches << Match.new(choice, score, index) if score >= cutoff
    end
    matches.sort_by! { |match| {-match.score, match.index} }
    limit ? matches.first(limit) : matches
  end

  # The best match for *query* in *choices*, or `nil` when nothing reaches
  # *cutoff*. Takes the same arguments as `extract`.
  #
  # ```
  # FuzzyMatch.extract_one("dallas", teams).try &.choice   # => "Dallas Cowboys"
  # FuzzyMatch.extract_one("vikings", teams, cutoff: 80.0) # => nil
  # ```
  def self.extract_one(query : String, choices : Enumerable(String), scorer : Scorer = :weighted_ratio,
                       cutoff : Float64 = 0.0) : Match?
    extract(query, choices, scorer, limit: 1, cutoff: cutoff).first?
  end

  # :ditto:
  def self.extract_one(query : String, choices : Enumerable(String), cutoff : Float64 = 0.0,
                       & : String, String -> Float64) : Match?
    extract(query, choices, limit: 1, cutoff: cutoff) { |a, b| yield a, b }.first?
  end
end
