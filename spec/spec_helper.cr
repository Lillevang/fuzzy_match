require "spec"
require "../src/fuzzy_match"

# Reference scores in the specs were produced with rapidfuzz 3.14 (Python),
# which fuzzy_match follows; they are checked to two decimals.
TOLERANCE = 0.005
