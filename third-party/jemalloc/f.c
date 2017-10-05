#include <stdio.h>
#include <string.h>
#include <assert.h>
#define JEMALLOC_NO_DEMANGLE

#include "jemalloc/jemalloc.h"

static extent_hooks_t *old_hooks;

static void* extent_alloc(extent_hooks_t *extent_hooks, void *new_addr, size_t size, size_t alignment, bool *zero, bool *commit, unsigned arena_ind) {
  printf("Entering extent hook\n");
  return old_hooks->alloc(extent_hooks, new_addr, size, alignment, zero, commit, arena_ind);
}

int main () {
  unsigned int arenas;
  size_t size = sizeof(unsigned int);
  // get the number of arenas
  assert(je_mallctl("arenas.narenas", &arenas, &size, NULL, 0) == 0);
  printf("There are %d arenas\n", (int)arenas);

  // grab a copy of the default extent_hooks
  size = sizeof(extent_hooks_t*);
  assert(je_mallctl("arena.0.extent_hooks", &old_hooks, &size, NULL, 0) == 0);
 
  // setup "new" hooks, old hooks but alloc calls new shim
  extent_hooks_t * new_hooks = malloc(sizeof(extent_hooks_t));
  memcpy(new_hooks, old_hooks, sizeof(extent_hooks_t));
  new_hooks->alloc = extent_alloc;

  // initialize all arenas with "thread.arena" call, then replace the extent
  // hooks for all arenas, finally reset current "thread.arena" to 0
  unsigned arena;
  for (arena=0; arena<arenas; arena++) {
    char path[128];
    snprintf(path, sizeof(path), "arena.%u.extent_hooks", arena);
    assert(je_mallctl("thread.arena", NULL, NULL, &arena, sizeof(arena)) == 0);
    assert(je_mallctl(path, NULL, NULL, &new_hooks, sizeof(extent_hooks_t*)) ==0);
  }
  arena = 0;
  assert(je_mallctl("thread.arena", NULL, NULL, &arena, sizeof(arena)) == 0);

  // make an allocation that'll require a new extent
  printf("%p\n", je_malloc(100000000));
}
