use CTypes;
use CRealloc;

config const size = 256 * 1024 * 1024;
config const numTasks = max(here.maxTaskPar, max(int(8)));

config const trials = 3;
coforall i in 1..here.maxTaskPar {
  var taskid = i % max(int(8));
  for 1..trials {
    var m = c_malloc(int(8), size);
    c_memset(m, taskid, size);
    assert(m[0] == taskid && m[size-1] == taskid);
    c_free(m);

    var r: c_ptr(int(8)); r = c_realloc(r, size);
    c_memset(r, taskid, size);
    assert(r[0] == taskid && r[size-1] == taskid);
    c_free(r);

    var a = c_aligned_alloc(int(8), 8, size);
    c_memset(a, taskid, size);
    assert(a[0] == taskid && a[size-1] == taskid);
    c_free(a);

    var c = c_calloc(int(8), size);
    assert(c[0] == 0 && c[size-1] == 0);
    c_free(c);
  }
}
