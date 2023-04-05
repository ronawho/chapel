use CommDiagnostics, Memory.Diagnostics, Time, CTypes;

config const size = 10,
             printRecords = false;

enum diagMode { performance, correctness, commCount, verboseComm, verboseMem };
config const mode = diagMode.performance;

config const trials = if mode == diagMode.performance then 100 else 1;

var t: stopwatch;
proc startDiag() {
  select(mode) {
    when diagMode.performance { t.start(); }
    when diagMode.commCount   { startCommDiagnostics(); }
    when diagMode.verboseComm { startVerboseComm(); }
    when diagMode.verboseMem  { startVerboseMem(); }
    otherwise                 { halt("Unrecognized diagMode"); }
  }
}

proc stopDiag(name) {
  select(mode) {
    when diagMode.performance {
      t.stop();
      writeln(name, "(", trials, "): ", t.elapsed());
      t.clear();
    }
    when diagMode.commCount {
      stopCommDiagnostics();
      const d = getCommDiagnostics();
      writeln(name, "-GETS: ", + reduce (d.get + d.get_nb));
      writeln(name, "-PUTS: ", + reduce (d.put + d.put_nb));
      writeln(name, "-ONS: ", + reduce (d.execute_on + d.execute_on_fast +
                                        d.execute_on_nb));
      resetCommDiagnostics();
    }
    when diagMode.verboseComm { stopVerboseComm(); writeln();}
    when diagMode.verboseMem  { stopVerboseMem(); }
    otherwise                 { halt("Unrecognized diagMode"); }
  }
}
// Record that will be locale to each locale

record foo {
  var Space = {1..size, 1..size};
  var data: [Space] int;

  proc init(val = 0) {
    data = val;
  }
}

iter broadcastIter(const in toBroadcast) { }

config const numChildren = ceil(sqrt(numLocales)):int;
iter broadcastIter(const in toBroadcast, param tag: iterKind) where tag == iterKind.standalone {
  const startChild = here.id*numChildren + 1;
  coforall locid in startChild..<min(startChild+numChildren,numLocales) do on Locales[locid] {
    const startChild = here.id*numChildren + 1;
    coforall locid in startChild..<min(startChild+numChildren,numLocales) do on Locales[locid] {
      yield toBroadcast;
    }
    yield toBroadcast;
  }
  yield toBroadcast;
}

proc main() {
  var r = new foo(42);
  r.data[1,1] = 0;

  startDiag();
  for 1..trials {
    forall rc in broadcastIter(r) {
      process(rc);
    }
  }
  stopDiag("tree    ");
  verifyCounter();

  startDiag();
  for 1..trials {
    const rc = r;
    coforall loc in Locales do on loc {
      process(rc);
    }
  }
  stopDiag("coforall");
  verifyCounter();

  if printRecords then
    writeln("back home: ", r);
}

proc process(x) {
  if printRecords then
    writeln((here.id, x));

  incCounter();
  return + reduce x.data;
}

proc foo.chpl__serialize() {
  var locBuf: c_ptr(int) = c_ptrTo(data);
  return new serializedFoo(locBuf, (size*size), this.locale.id);
}

proc type foo.chpl__deserialize(in data: serializedFoo) {
  var r = new foo();

  import Communication as Comm;
  Comm.get(c_ptrTo(r.data), data.buff, data.locale_id,
           (data.size*c_sizeof(int)).safeCast(c_size_t));

  return r;
}

record serializedFoo {
  var buff: c_ptr(int);
  var size: int;
  var locale_id: int;
}

pragma "locale private" var counter = 0;
inline proc incCounter() { counter += 1; }
inline proc getCounter() { return counter; }
inline proc resCounter() { counter = 0; }
inline proc verifyCounter() {
  coforall loc in Locales do on loc {
    assert(getCounter() == trials);
    resCounter();
  }
}
