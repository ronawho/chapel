use GpuDiagnostics;


config const start = 1;
config const end = 10;

startGpuDiagnostics();
on here.gpus[0] {
  var a, b: [start..end] int;

  forall  (x,i) in zip(b, b.domain) do x = i+12;

  forall  (aElem, bElem) in zip(a, b) { aElem += bElem + 10;    } writeln(a);

  foreach bElem in b do bElem += 100;

  foreach (aElem, bElem) in zip(a, b) { aElem += bElem + 10;    } writeln(a);
}
stopGpuDiagnostics();
assertGpuDiags(kernel_launch_um=4, kernel_launch_aod=6);
