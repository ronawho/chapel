#!/usr/bin/env bash

# chpl test/studies/bale/aggregation/ig.chpl --fast -suseBlockArr --no-optimize-forall-unordered-ops

threads=(1 2 4 8 16 28)
for t in "${threads[@]}"; do
  export CHPL_RT_NUM_THREADS_PER_LOCALE=$t
  echo "Running with $t threads"
  ./ig -nl 16 
  echo ""
done
