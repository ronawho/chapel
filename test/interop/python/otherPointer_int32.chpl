use CTypes, OS.POSIX;

export proc gimmePointer(x: c_ptr(int(32))) {
  var y: int(32) = 4;
  memcpy(x, c_ptrTo(y), c_sizeof(y.type));
}

export proc writeInt(x: int(32)) {
  writeln(x);
}
