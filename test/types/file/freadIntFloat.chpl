use IO;

var myFirstInt: int = 999;
var myFirstFloat: real = 99.9;
var mySecondInt: int;

var f = open("freadIntFloat.txt", ioMode.r).reader(locking=false);

f.read(myFirstInt, myFirstFloat, mySecondInt);

writeln(myFirstInt);
writeln(myFirstFloat);
writeln(mySecondInt);
