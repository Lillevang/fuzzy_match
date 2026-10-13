require "./spec_helper"

describe FuzzyMatch do
  describe ".normalize" do
    it "lowercases, replaces punctuation with spaces and trims" do
      FuzzyMatch.normalize("  Hello, World! Øl & 123 ").should eq("hello world øl 123")
    end

    it "collapses runs of separators into one space" do
      FuzzyMatch.normalize("a---b  ,  c").should eq("a b c")
    end

    it "keeps letters outside ASCII" do
      FuzzyMatch.normalize("Blåbærgrød (ÆØÅ)").should eq("blåbærgrød æøå")
    end

    it "returns an empty string when nothing alphanumeric is left" do
      FuzzyMatch.normalize(" !?- ").should eq("")
      FuzzyMatch.normalize("").should eq("")
    end
  end

  describe ".ratio" do
    it "scores identical strings 100 and disjoint strings 0" do
      FuzzyMatch.ratio("abc", "abc").should eq(100.0)
      FuzzyMatch.ratio("abc", "xyz").should eq(0.0)
    end

    it "treats two empty strings as identical and one empty string as nothing in common" do
      FuzzyMatch.ratio("", "").should eq(100.0)
      FuzzyMatch.ratio("", "abc").should eq(0.0)
      FuzzyMatch.ratio("abc", "").should eq(0.0)
    end

    it "is the normalized indel similarity" do
      FuzzyMatch.ratio("this is a test", "this is a test!").should be_close(96.55, TOLERANCE)
      FuzzyMatch.ratio("kitten", "sitting").should be_close(61.54, TOLERANCE)
      FuzzyMatch.ratio("ab", "ba").should be_close(50.0, TOLERANCE)
      FuzzyMatch.ratio("New York Mets vs Atlanta Braves", "Atlanta Braves vs New York Mets").should be_close(45.16, TOLERANCE)
    end

    it "is symmetric" do
      FuzzyMatch.ratio("Danmark", "Denmark").should eq(FuzzyMatch.ratio("Denmark", "Danmark"))
    end

    it "is case sensitive unless asked to normalize" do
      FuzzyMatch.ratio("Crystal", "crystal").should be_close(85.71, TOLERANCE)
      FuzzyMatch.ratio("Crystal", "crystal", normalize: true).should eq(100.0)
    end

    it "compares characters, not bytes" do
      FuzzyMatch.ratio("København", "Kobenhavn").should be_close(88.89, TOLERANCE)
      FuzzyMatch.ratio("blåbærgrød", "blabaergrod").should be_close(66.67, TOLERANCE)
    end
  end

  describe ".partial_ratio" do
    it "scores 100 when the shorter string is contained in the longer" do
      FuzzyMatch.partial_ratio("abc", "zzzabczzz").should eq(100.0)
      FuzzyMatch.partial_ratio("hello world", "world").should eq(100.0)
      FuzzyMatch.partial_ratio("Jeppe", "Jeppe Lillevang Salling").should eq(100.0)
    end

    it "takes the best window of the longer string" do
      FuzzyMatch.partial_ratio("kitten", "sitting").should be_close(66.67, TOLERANCE)
      FuzzyMatch.partial_ratio("abc", "xxbc").should be_close(80.0, TOLERANCE)
      FuzzyMatch.partial_ratio("mariners vs angels", "los angeles angels of anaheim at seattle mariners").should be_close(61.54, TOLERANCE)
    end

    it "also considers windows hanging over either end" do
      FuzzyMatch.partial_ratio("xab", "abzzzz").should be_close(80.0, TOLERANCE)
      FuzzyMatch.partial_ratio("zzzzab", "abx").should be_close(80.0, TOLERANCE)
      FuzzyMatch.partial_ratio("ab", "ba").should be_close(66.67, TOLERANCE)
      FuzzyMatch.partial_ratio("Crystal", "crystal").should be_close(92.31, TOLERANCE)
    end

    it "handles empty strings like ratio" do
      FuzzyMatch.partial_ratio("", "").should eq(100.0)
      FuzzyMatch.partial_ratio("", "abc").should eq(0.0)
      FuzzyMatch.partial_ratio("abc", "").should eq(0.0)
    end

    it "can normalize first" do
      FuzzyMatch.partial_ratio("JETS!", "New York Jets", normalize: true).should eq(100.0)
    end
  end

  describe ".token_sort_ratio" do
    it "ignores word order" do
      FuzzyMatch.token_sort_ratio("fuzzy wuzzy was a bear", "wuzzy fuzzy was a bear").should eq(100.0)
      FuzzyMatch.token_sort_ratio("New York Mets vs Atlanta Braves", "Atlanta Braves vs New York Mets").should eq(100.0)
    end

    it "still penalizes different words" do
      FuzzyMatch.token_sort_ratio("mariners vs angels", "los angeles angels of anaheim at seattle mariners").should be_close(50.75, TOLERANCE)
      FuzzyMatch.token_sort_ratio("Copenhagen Airport", "Airport Copenhagen Kastrup").should be_close(81.82, TOLERANCE)
    end

    it "normalizes by default and can be told not to" do
      FuzzyMatch.token_sort_ratio("B a", "a b").should eq(100.0)
      FuzzyMatch.token_sort_ratio("B a", "a b", normalize: false).should be_close(33.33, TOLERANCE)
    end

    it "scores two empty strings 100" do
      FuzzyMatch.token_sort_ratio("", "").should eq(100.0)
    end
  end

  describe ".token_set_ratio" do
    it "scores 100 when one string's words are all in the other" do
      FuzzyMatch.token_set_ratio("fuzzy was a bear", "fuzzy fuzzy was a bear").should eq(100.0)
      FuzzyMatch.token_set_ratio("Lillevang", "Lillevang Consult ApS").should eq(100.0)
      FuzzyMatch.token_set_ratio("Copenhagen Airport", "Airport Copenhagen Kastrup").should eq(100.0)
    end

    it "ignores duplicated words" do
      FuzzyMatch.token_set_ratio("a a", "a").should eq(100.0)
    end

    it "compares the leftovers after removing the shared words" do
      FuzzyMatch.token_set_ratio("mariners vs angels", "los angeles angels of anaheim at seattle mariners").should be_close(90.91, TOLERANCE)
    end

    it "falls back to a plain ratio when no words are shared" do
      FuzzyMatch.token_set_ratio("kitten", "sitting").should be_close(61.54, TOLERANCE)
      FuzzyMatch.token_set_ratio("abc", "xyz").should eq(0.0)
    end

    it "scores 0 when either side has no words" do
      FuzzyMatch.token_set_ratio("", "").should eq(0.0)
      FuzzyMatch.token_set_ratio("abc", "").should eq(0.0)
      FuzzyMatch.token_set_ratio("abc", " !! ").should eq(0.0)
    end
  end

  describe ".partial_token_sort_ratio" do
    it "matches sorted words with partial_ratio" do
      FuzzyMatch.partial_token_sort_ratio("fuzzy was a bear", "fuzzy fuzzy was a bear").should be_close(89.66, TOLERANCE)
      FuzzyMatch.partial_token_sort_ratio("mariners vs angels", "los angeles angels of anaheim at seattle mariners").should be_close(72.22, TOLERANCE)
    end
  end

  describe ".partial_token_set_ratio" do
    it "scores 100 for any shared word" do
      FuzzyMatch.partial_token_set_ratio("mariners vs angels", "los angeles angels of anaheim at seattle mariners").should eq(100.0)
    end

    it "uses partial_ratio on the leftovers otherwise" do
      FuzzyMatch.partial_token_set_ratio("abc def", "abd xyz").should be_close(60.0, TOLERANCE)
      FuzzyMatch.partial_token_set_ratio("kitten", "sitting").should be_close(66.67, TOLERANCE)
    end

    it "scores 0 when either side has no words" do
      FuzzyMatch.partial_token_set_ratio("", "").should eq(0.0)
    end
  end

  describe ".weighted_ratio" do
    it "uses the plain and token scorers for strings of similar length" do
      FuzzyMatch.weighted_ratio("kitten", "sitting").should be_close(61.54, TOLERANCE)
      FuzzyMatch.weighted_ratio("fuzzy wuzzy was a bear", "wuzzy fuzzy was a bear").should be_close(95.0, TOLERANCE)
      FuzzyMatch.weighted_ratio("this is a test", "this is a test!").should eq(100.0)
    end

    it "scales down partial matches when the lengths differ a lot" do
      FuzzyMatch.weighted_ratio("hello world", "world").should be_close(90.0, TOLERANCE)
      FuzzyMatch.weighted_ratio("abc", "zzzabczzz").should be_close(90.0, TOLERANCE)
      FuzzyMatch.weighted_ratio("mariners vs angels", "los angeles angels of anaheim at seattle mariners").should be_close(85.5, TOLERANCE)
      FuzzyMatch.weighted_ratio("abc", "abc" + "x" * 30).should be_close(60.0, TOLERANCE)
    end

    it "normalizes by default" do
      FuzzyMatch.weighted_ratio("Crystal", "crystal").should eq(100.0)
    end

    it "scores 0 when either string is empty" do
      FuzzyMatch.weighted_ratio("", "").should eq(0.0)
      FuzzyMatch.weighted_ratio("abc", "").should eq(0.0)
    end
  end

  describe ".extract" do
    teams = ["Atlanta Falcons", "New York Jets", "New York Giants", "Dallas Cowboys"]

    it "returns every choice sorted best first" do
      matches = FuzzyMatch.extract("new york jets", teams, scorer: :ratio)
      matches.map(&.choice).should eq(["New York Jets", "New York Giants", "Atlanta Falcons", "Dallas Cowboys"])
      matches.map(&.index).should eq([1, 2, 0, 3])
      matches.first.score.should be_close(76.92, TOLERANCE)
    end

    it "uses weighted_ratio by default" do
      matches = FuzzyMatch.extract("new york jets", teams, limit: 2)
      matches.size.should eq(2)
      matches[0].should eq(FuzzyMatch::Match.new("New York Jets", 100.0, 1))
      matches[1].choice.should eq("New York Giants")
      matches[1].score.should be_close(78.57, TOLERANCE)
    end

    it "drops matches below the cutoff" do
      FuzzyMatch.extract("cowboys", teams, scorer: :ratio, cutoff: 90.0).should be_empty
      FuzzyMatch.extract("cowboys", teams, cutoff: 90.0).map(&.choice).should eq(["Dallas Cowboys"])
    end

    it "keeps the order of the choices for ties" do
      matches = FuzzyMatch.extract("hello", ["hello world", "help", "yellow", "world hello"], cutoff: 80.0)
      matches.map(&.choice).should eq(["hello world", "world hello"])
      matches.map(&.score).should eq([90.0, 90.0])
    end

    it "accepts any enumerable of strings" do
      FuzzyMatch.extract("dallas", Set{"Dallas Cowboys", "Atlanta Falcons"}, limit: 1).first.choice.should eq("Dallas Cowboys")
    end

    it "takes a block as a custom scorer" do
      matches = FuzzyMatch.extract("CRYSTAL", ["crystal", "ruby"]) { |a, b| FuzzyMatch.ratio(a, b, normalize: true) }
      matches.first.should eq(FuzzyMatch::Match.new("crystal", 100.0, 0))
    end

    it "returns nothing for no choices" do
      FuzzyMatch.extract("anything", [] of String).should be_empty
    end
  end

  describe ".extract_one" do
    teams = ["Atlanta Falcons", "New York Jets", "New York Giants", "Dallas Cowboys"]

    it "returns the best match" do
      FuzzyMatch.extract_one("dallas", teams).try(&.choice).should eq("Dallas Cowboys")
      FuzzyMatch.extract_one("giants", teams, scorer: :partial_ratio).try(&.choice).should eq("New York Giants")
    end

    it "returns nil when nothing reaches the cutoff" do
      FuzzyMatch.extract_one("vikings", teams, cutoff: 80.0).should be_nil
      FuzzyMatch.extract_one("vikings", [] of String).should be_nil
    end

    it "takes a block as a custom scorer" do
      best = FuzzyMatch.extract_one("jets", teams) { |a, b| FuzzyMatch.partial_ratio(a, b, normalize: true) }
      best.try(&.choice).should eq("New York Jets")
    end
  end
end
