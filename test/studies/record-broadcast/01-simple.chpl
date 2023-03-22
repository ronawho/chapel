use CommDiagnostics, Time, CTypes;

config const size = 10,
             printRecords = false,
             printDiagnotics = true;

// Record that will be locale to each locale

record foo {
  var Space = {1..size, 1..size};
  var data: [Space] int;

  proc init(val = 0) {
    data = val;
  }
}

proc main() {
  const r = new foo(42);

  startCommDiagnostics();

  coforall loc in Locales do on loc {

    process(r);
  }

  stopCommDiagnostics();
  printCommDiagnosticsTable();

  if printRecords then
    writeln("back home: ", r);
}

proc process(x) {
  if printRecords then
    writeln((here.id, x));

  return + reduce x.data;
}
