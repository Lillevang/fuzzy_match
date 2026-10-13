# fuzzy_match

**Fuzzy string matching for Crystal. The scorers of `fuzzywuzzy` and `rapidfuzz`, with no dependencies.**

[![CI](https://img.shields.io/github/actions/workflow/status/Lillevang/fuzzy_match/ci.yml?branch=main&label=ci)](https://github.com/Lillevang/fuzzy_match/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Lillevang/fuzzy_match?display_name=tag)](https://github.com/Lillevang/fuzzy_match/releases/latest)
[![Docs](https://img.shields.io/badge/docs-API-blue)](https://lillevang.github.io/fuzzy_match/)
[![Crystal](https://img.shields.io/badge/built%20with-Crystal-000000?logo=crystal)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Real-world input is messy: typos, different word order, a surname where the
full name was expected, `A/S` here and `ApS` there. `fuzzy_match` tells you how
alike two strings are on a 0 to 100 scale, with a handful of scorers that each
forgive a different kind of mess, and finds the best match in a list.

```crystal
require "fuzzy_match"

FuzzyMatch.ratio("this is a test", "this is a test!")                   # => 96.55
FuzzyMatch.partial_ratio("Lillevang", "Lillevang Consult ApS")          # => 100.0
FuzzyMatch.token_sort_ratio("nordisk novo", "Novo Nordisk A/S")         # => 85.71
FuzzyMatch.token_set_ratio("nordisk novo", "Novo Nordisk A/S")          # => 100.0
FuzzyMatch.weighted_ratio("carlsbreg", "Carlsberg Breweries A/S")       # => 80.0

companies = ["Lillevang Consult ApS", "Novo Nordisk A/S", "LEGO System A/S"]
FuzzyMatch.extract_one("legosystem", companies).try &.choice            # => "LEGO System A/S"
```

The scores follow the definitions used by Python's
[rapidfuzz](https://github.com/rapidfuzz/RapidFuzz) (and fuzzywuzzy before
it), so thresholds tuned there carry over. The spec suite pins every scorer to
values cross-checked against rapidfuzz.

## Scorers

Every scorer takes two strings and returns a `Float64` between `0.0` and `100.0`.

| Scorer                       | Forgives                                  | Example                                                  |
| ---------------------------- | ----------------------------------------- | -------------------------------------------------------- |
| `ratio`                      | Nothing. Plain edit similarity.           | `"kitten"` / `"sitting"` → 61.5                          |
| `partial_ratio`              | One string being a fragment of the other. | `"world"` / `"hello world"` → 100                        |
| `token_sort_ratio`           | Word order.                               | `"nordisk novo"` / `"Novo Nordisk A/S"` → 85.7           |
| `token_set_ratio`            | Word order, duplicates and extra words.   | `"nordisk novo"` / `"Novo Nordisk A/S"` → 100            |
| `partial_token_sort_ratio`   | Word order, then fragments.               |                                                          |
| `partial_token_set_ratio`    | Any word in common scores 100.            |                                                          |
| `weighted_ratio`             | All of the above, weighted by length.     | `"carlsbreg"` / `"Carlsberg Breweries A/S"` → 80         |

`ratio` is the normalized *indel* similarity: how many insertions and deletions
turn one string into the other, relative to the combined length. Everything
else is built on it. `partial_ratio` slides the shorter string over the longer
one and keeps the best window, including windows that hang over either end, so
`"Crystal"` against `"crystal"` scores 92.3 rather than 85.7.

`weighted_ratio` is the all-rounder and the default for `extract`. For strings
of similar length it takes the best of `ratio` and the token scorers; when one
string is much longer, it switches to the partial scorers and scales their
result down so an exact match still outranks a fragment.

### Normalization

The token scorers and `weighted_ratio` normalize their input first: lowercase,
every run of punctuation or whitespace becomes a single space, ends trimmed.
`ratio` and `partial_ratio` compare exactly what they are given. Both defaults
can be flipped with `normalize:`.

```crystal
FuzzyMatch.normalize("  Hello, World! Øl & 123 ")       # => "hello world øl 123"
FuzzyMatch.ratio("Crystal", "crystal")                   # => 85.71
FuzzyMatch.ratio("Crystal", "crystal", normalize: true)  # => 100.0
FuzzyMatch.token_sort_ratio("B a", "a b", normalize: false) # => 33.33
```

Strings are compared character by character, not byte by byte, so `æ`, `ø` and
`å` count as one edit each, and normalization keeps every Unicode letter.

## Finding the best match

`extract` scores a query against a list and returns the matches best first.
`extract_one` returns only the winner, or `nil`.

```crystal
teams = ["Atlanta Falcons", "New York Jets", "New York Giants", "Dallas Cowboys"]

FuzzyMatch.extract("new york jets", teams, limit: 2)
# => [Match(@choice="New York Jets", @score=100.0, @index=1),
#     Match(@choice="New York Giants", @score=78.57, @index=2)]

FuzzyMatch.extract("cowboys", teams, scorer: :ratio, cutoff: 90.0)  # => []
FuzzyMatch.extract_one("dallas", teams).try &.choice                 # => "Dallas Cowboys"
FuzzyMatch.extract_one("vikings", teams, cutoff: 80.0)              # => nil
```

- `scorer:` picks any of the scorers above by name. The default is `:weighted_ratio`.
- `limit:` caps the number of matches; `cutoff:` drops everything scoring below it.
- Ties keep the order of the input, and each `Match` carries the `index` it came from.
- Pass a block instead of `scorer:` to score with your own function:

```crystal
FuzzyMatch.extract("CRYSTAL", langs) { |a, b| FuzzyMatch.ratio(a, b, normalize: true) }
```

## Installation

Add the dependency to your `shard.yml` and run `shards install`:

```yaml
dependencies:
  fuzzy_match:
    github: Lillevang/fuzzy_match
    version: ~> 0.1.0
```

Requires [Crystal](https://crystal-lang.org/install/) 1.15 or newer. There are
no runtime dependencies.

## Example

`examples/demo.cr` runs a few messy queries against a list of company names
with every scorer, which is a good way to get a feel for how they differ:

```
$ crystal run examples/demo.cr
fuzzy_match 0.1.0

query: "lillevang consult"
                                ratio    partial token_sort  token_set   weighted
  Lillevang Consult ApS          78.9       88.2       89.5      100.0       95.0
  Novo Nordisk A/S               24.2       28.6       24.2       24.2       24.2
  LEGO System A/S                18.8       26.1       25.0       25.0       37.5
  Carlsberg Breweries A/S        25.0       29.6       25.0       25.0       30.0
  Danske Bank A/S                25.0       32.0       25.0       25.0       31.2
  → "Lillevang Consult ApS" (weighted 95.0)

query: "carlsbreg"
                                ratio    partial token_sort  token_set   weighted
  Lillevang Consult ApS          20.0       33.3       26.7       26.7       34.2
  Novo Nordisk A/S               16.0       22.2       24.0       24.0       30.2
  LEGO System A/S                16.7       23.5       33.3       33.3       48.9
  Carlsberg Breweries A/S        43.8       77.8       50.0       50.0       80.0
  Danske Bank A/S                25.0       40.0       25.0       25.0       36.0
  → "Carlsberg Breweries A/S" (weighted 80.0)
```

## Development

Every check and publish step is a [Task](https://taskfile.dev) command in
`Taskfile.yml`, so what runs in CI is exactly what runs on a laptop.

```bash
task            # same as task verify
task verify     # format check, specs, example smoke test, docs build
task test       # just the specs
task fmt        # format sources in place
task docs       # API docs into docs/
```

### Releasing

```bash
task bump                 # 0.1.0 → 0.1.1 (TARGET=minor|major for the others)
git commit -am "Bump to 0.1.1"
task release              # verify, tag v0.1.1, push
```

Pushing the tag triggers `.github/workflows/release.yml`, a thin wrapper that
runs `task check-tag`, `task verify` and `task publish` and creates the GitHub
release with generated notes. A shard is consumed as source, so there are no
binaries to attach. The workflow holds no logic of its own: `task publish` cuts
the same release from any machine with `gh`.

`release` refuses to run from a dirty tree, from a branch other than `main`, or
for a tag that already exists. The version lives in `src/fuzzy_match.cr` and is
mirrored in `shard.yml`; `bump` keeps the two in sync and `check-tag` makes sure
the pushed tag matches.

`.github/workflows/ci.yml` runs `task verify` on every push and pull request
and publishes the generated API docs to
[GitHub Pages](https://lillevang.github.io/fuzzy_match/) from `main`.

## License

[MIT](LICENSE) © [Jeppe Lillevang Salling](https://github.com/Lillevang)
