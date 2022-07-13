use BlockDist, CopyAggregation;

config const n = 100;
var A = newBlockArr(1..n*2, int);
A[n+1..n*2] = 1;

on Locales[numLocales-1] {
  forall i in 1..n with (var agg = new DstAggregator(int)) {
    agg.copy(A[i], A[i+n]);
  }
}
//writeln(A);
assert(A==1);
