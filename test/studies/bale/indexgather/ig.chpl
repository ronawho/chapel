use CyclicDist;
use BlockDist;
use Random;
use Time;
use PrivateDist;
use ChapelAutoAggregation.CopyAggregation;

config const largeAggs = 8;

config const printStats = true,
             printArrays = false,
             verify = true;

config const useRandomSeed = true,
             seed = if useRandomSeed then SeedGenerator.oddCurrentTime else 314159265;

enum Mode {ordered, unordered, aggregated}
config const mode = Mode.ordered;

const numTasksPerLocale = if dataParTasksPerLocale > 0 then dataParTasksPerLocale
                                                       else here.maxTaskPar;
const numTasks = numLocales * numTasksPerLocale;
config const N = 1000000; // number of updates per task
config const M = 10000; // number of entries in the table per task

const numUpdates = N * numTasks;
const tableSize = M * numTasks;

// The intuitive implementation of indexgather that uses fine-grained GETs
proc main() {
  const Mspace = {0..tableSize-1};
  const D = Mspace dmapped Cyclic(startIdx=Mspace.low);
  var A: [D] int = 0..tableSize-1;

  const Nspace = {0..numUpdates-1};
  const D2 = Nspace dmapped Block(Nspace);
  var rindex: [D2] int;

  fillRandom(rindex, seed);
  forall r in rindex {
    r = mod(r, tableSize);
  }

  var tmp: [D2] int = -1;
  var t: Timer; t.start();
  {
    const aggD = newBlockDom(0..<numLocales);
    var aggs: [aggD] unmanaged MultiSrcAggregator(int) = [aggD] new unmanaged MultiSrcAggregator(int, numAggs=largeAggs);

    forall i in D2 with (ref parents = aggs[here.id], var agg = new LocalSrcAggregator(int, parents=parents)) do
      agg.copy(tmp[i], A[rindex[i]]);

    [a in aggs] delete a;
  }
  t.stop();

  if printStats {
    writeln("Time: ", t.elapsed());

    const bytesPerTask = N * numBytes(int);
    const mbPerTask = bytesPerTask:real / (1<<20):real;
    writeln("MB/s per task: ", mbPerTask / t.elapsed());
    writeln("MB/s per node: ", mbPerTask * numTasksPerLocale / t.elapsed());
  }

  if printArrays {
    writeln(tmp);
  }

  if verify {
    [t in tmp] assert (t >= 0 && t < tableSize);
  }

}
