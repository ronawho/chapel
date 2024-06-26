var A: [1..10 by 2] real;
var B: [1..10 by 2 align 2] real;
var C: [1..10 by -2] real;        // neg-stride

forall i in A.domain with (ref A) do
  A[i] = i;

forall i in B.domain with (ref B) do
  B[i] = i;

forall i in C.domain with (ref C) do
  C[i] = i;

writeln(A.last);
writeln(B.first);
writeln(C.first);
writeln(C.last);

