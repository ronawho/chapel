import Map.map;

proc testMap(type t, param testIndexing = false) where isBorrowedClass(t) {

  var m = new map(int, t);

  // create values with 'owned' if t is a borrowed class type
  // (the map will still store borrowed)
  type useT = (t:owned);

  var x: useT = new useT(1);

  var ret = m.add(1, x.borrow());
  assert(ret);

  assert(m.contains(1));
  var y: useT = new useT(-1);

  ret = m.add(1, y.borrow());
  assert(!ret);
  for v in m.values() do writeln(v);  // still '1'

  ret = m.remove(1);
  assert(ret);
  assert(!m.contains(1));
  assert(!m.contains(2));

  if isNilableClass(t) {
    ret = m.add(0, nil:t);
    assert(ret);
    var n = m[0];
    assert(n == nil);
    ret = m.remove(0);
    assert(ret);
  }

  if isNilableClass(t) || testIndexing {
    var z: useT = new useT(3);
    m[3] = z.borrow();

    assert(m.contains(3));

    var zz: t = m[3];

    ret = m.remove(3);
    assert(ret);

    if isUnmanagedClass(t) {
      delete z;
    }
  }
}

/* Tests indexing only for nilable classes.  testIndexing arg allows
 * overriding to test the error for nonnilable, and to test indexing
 * for records. */
proc testMap(type t, param testIndexing = false) {

  var m = new map(int, t);

  var x: t;
  x = if isTuple(t) then (new t[0](1), new t[1](2)) else new t(1);

  var ret = m.add(1, x);
  assert(ret);

  assert(m.contains(1));
  var y: t;
  y = if isTuple(t) then (new t[0](-1), new t[1](-2)) else new t(-1);

  ret = m.add(1, y);
  assert(!ret);
  for v in m.values() do writeln(v);  // still '1'

  ret = m.remove(1);
  assert(ret);
  assert(!m.contains(1));
  assert(!m.contains(2));

  if isNilableClass(t) {
    ret = m.add(0, nil:t);
    assert(ret);
    var n = m[0];
    assert(n == nil);
    ret = m.remove(0);
    assert(ret);
  }

  if isNilableClass(t) || testIndexing {
    var z: t;
    z = if isTuple(t) then (new t[0](3), new t[1](4)) else new t(3);
    m[3] = z;

    assert(m.contains(3));

    var zz: t = m[3];

    ret = m.remove(3);
    assert(ret);

    if isUnmanagedClass(t) {
      delete z;
    }
  }

  if isUnmanagedClass(t) {
    delete x;
    delete y;
  }
}
