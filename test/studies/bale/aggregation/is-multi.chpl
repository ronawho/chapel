use CyclicDist;
use BlockDist;
use Random;
use Time;
use PrivateDist;
use CopyAggregation;

config const largeAggs = 8;

const numTasksPerLocale = if dataParTasksPerLocale > 0 then dataParTasksPerLocale
                                                       else here.maxTaskPar;
const numTasks = numLocales * numTasksPerLocale;
config const N = 1000000; // number of updates per task
config const M = 10000; // number of entries in the table per task

const numUpdates = N * numTasks;
const tableSize = M * numTasks;

// Block array access is faster than Cyclic currently. We hadn't optimized
// these before because the comm overhead dominated, but that's no longer true
// with aggregation. `-suseBlockArr` and/or `-sdefaultDisableLazyRADOpt` will
// help indexing speed until we optimize them.
config param useBlockArr = false;

var t: Timer;
proc startTimer() {
  t.start();
}
proc stopTimer(name) {
    t.stop(); var src = t.elapsed(); t.clear();
    const bytesPerTask = 2 * N * numBytes(int);
    const gbPerNode = bytesPerTask:real / (10**9):real * numTasksPerLocale;
    writef("%10s:\t%.3dr seconds\t%.3dr GB/s/node\n", name, src, gbPerNode/src);
}

proc main() {
  const D = if useBlockArr then newBlockDom(0..#tableSize)
                           else newCyclicDom(0..#tableSize);
  var A: [D] int = D;

  const UpdatesDom = newBlockDom(0..#numUpdates);
  var Rindex: [UpdatesDom] int;

  fillRandom(Rindex, 208);
  Rindex = mod(Rindex, tableSize);
  var tmp: [UpdatesDom] int = -1;

  startTimer();

  const aggD = newBlockDom(0..<numLocales);
  var aggs: [aggD] unmanaged MultiDstAggregator(int) = [aggD] new unmanaged MultiDstAggregator(int, numAggs=largeAggs);
  forall (t, r) in zip (tmp, Rindex) with (ref parents = aggs[here.id], var agg = new LocalDstAggregatorImpl(int, parents=parents)) {
    agg.copy(A[r], t);
  }
  [a in aggs] delete a;
  stopTimer("AGG");
}
