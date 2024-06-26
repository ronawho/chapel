use BlockDist;

proc createNiceArray() {
  var dom = {1..10} dmapped blockDist({1..10});
  var arr: [dom] int;

  return arr;
}

proc createAnnoyingArray() {
  var dom = {1..10} dmapped blockDist({1..20});
  var arr: [dom] int;

  return arr;
}


var arr1 = createNiceArray();
var arr2 = createAnnoyingArray();

arr1 = 1;
arr2 = 2;

forall i in arr2.domain with (ref arr1) {
  arr1[i] =
    arr2[i];
}

writeln(arr1);
