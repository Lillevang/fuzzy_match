# Matches a few messy inputs against a canonical list with every scorer, to
# show where they differ. Run with `crystal run examples/demo.cr` or `task smoke`.
require "../src/fuzzy_match"

companies = [
  "Lillevang Consult ApS",
  "Novo Nordisk A/S",
  "LEGO System A/S",
  "Carlsberg Breweries A/S",
  "Danske Bank A/S",
]
queries = ["lillevang consult", "nordisk novo", "legosystem", "carlsbreg"]
scorers = {
  "ratio"      => FuzzyMatch::Scorer::Ratio,
  "partial"    => FuzzyMatch::Scorer::PartialRatio,
  "token_sort" => FuzzyMatch::Scorer::TokenSortRatio,
  "token_set"  => FuzzyMatch::Scorer::TokenSetRatio,
  "weighted"   => FuzzyMatch::Scorer::WeightedRatio,
}

puts "fuzzy_match #{FuzzyMatch::VERSION}"
queries.each do |query|
  puts
  puts "query: #{query.inspect}"
  puts "  %-24s%s" % {"", scorers.keys.map(&.rjust(11)).join}
  companies.each do |company|
    scores = scorers.values.map { |scorer| ("%.1f" % scorer.call(query, company)).rjust(11) }
    puts "  %-24s%s" % {company, scores.join}
  end
  if best = FuzzyMatch.extract_one(query, companies)
    puts "  → #{best.choice.inspect} (weighted #{best.score.round(1)})"
  end
end
