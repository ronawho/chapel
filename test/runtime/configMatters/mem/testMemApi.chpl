use CTypes;

// check a couple of sizes can be allocated and freed
var sizes = (0, 1, 16, 17, 1000);
for size in sizes {
  var m = c_malloc(int, size);
  var c = c_calloc(int, size);
  var a = c_aligned_alloc(int, 8, size);
  var r: c_ptr(int); r = c_realloc(int, r, size);
  c_free(m);
  c_free(a);
  c_free(c);
  c_free(r);
}

// check that calloc zeros
var c = c_calloc(int, 1);
assert(c[0] == 0);
c[0] = 1;
c_free(c);
c = c_calloc(int, 1);
assert(c[0] == 0);
c_free(c);


// check that alloc then realloc works
var m = c_malloc(int, 1);
m[0] = 1;
assert(m[0] == 1);
m = c_realloc(int, m, 21);
assert(m[0] == 1);
m[20] = 1;
c_free(m);

// check that free/realloc with NULL pointer works, and 0 size realloc frees
var n: c_ptr(int);
c_free(n);
c_realloc(int, n, 0);

var r = c_realloc(int, c_nil, 1);
r[0] = 1;
c_realloc(int, r, 0);
