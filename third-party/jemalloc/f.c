#include <stdio.h>
#include <string.h>

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
  if (je_mallctl("arenas.narenas", &arenas, &size, NULL, 0)) {
    printf("narenas failure\n");
  }
  printf("%d arenas\n", (int) arenas);

  size = sizeof(extent_hooks_t*);
  if (je_mallctl("arena.0.extent_hooks", &old_hooks, &size, NULL, 0)) {
    printf("extent get hooks failure\n");
  }
  
  extent_hooks_t * new_hooks = malloc(sizeof(extent_hooks_t));
  memcpy(new_hooks, old_hooks, sizeof(extent_hooks_t));
  //new_hooks->alloc = extent_alloc;

  unsigned arena;

  for (arena=0; arena<arenas; arena++) {
    char path[128];
    snprintf(path, sizeof(path), "arena.%u.extent_hooks", arena);
    if (je_mallctl("thread.arena", NULL, NULL, &arena, sizeof(arena)) != 0) {
      printf("could not change current thread's arena");
    }
    if (je_mallctl(path, NULL, NULL, &new_hooks, sizeof(extent_hooks_t*)) != 0) {
      printf("extent set hooks failure\n");
    }
  }

  arena = 0;
  if (je_mallctl("thread.arena", NULL, NULL, &arena, sizeof(arena)) != 0) {
      printf("could not change current thread's arena back to 0");
  }


//  if (je_mallctl("arena.1.extent_hooks", NULL, NULL, &new_hooks, sizeof(extent_hooks_t*))) {
//    printf("extent set hooks failure\n");
//  }

  printf("%p\n", chpl_je_malloc(100000000));




//  for(unsigned int i = 0; i < arenas; i++) {
//      char buffer[25];
//      
//      snprintf(buffer, 25, "arena.%d.chunk_hooks", i);
//
//      size_t chunk_struct_size = sizeof(chunk_hooks_t);
//
//      je_mallctl(buffer, NULL, NULL, &mm_hooks, chunk_struct_size);
//  }
}
