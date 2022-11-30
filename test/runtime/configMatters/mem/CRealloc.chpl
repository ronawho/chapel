use CTypes;

private proc offset_ARRAY_ELEMENTS {
  extern const CHPL_RT_MD_ARRAY_ELEMENTS:chpl_mem_descInt_t;
  pragma "fn synchronization free"
  extern proc chpl_memhook_md_num(): chpl_mem_descInt_t;
  return CHPL_RT_MD_ARRAY_ELEMENTS - chpl_memhook_md_num();
}

/*
inline proc c_realloc(type eltType, data: c_ptr(eltType), size: integral) : c_ptr(eltType) {
  const alloc_size = size.safeCast(c_size_t) * c_sizeof(eltType);
  return chpl_here_realloc(data, alloc_size, offset_ARRAY_ELEMENTS):c_ptr(eltType);
}
*/


// Draft of what c_realloc API might look like. Should there be a c_void_ptr
// overload?
inline proc c_realloc(data: c_ptr(?eltType), size: integral) : c_ptr(eltType) {
  const alloc_size = size.safeCast(c_size_t) * c_sizeof(eltType);
  return chpl_here_realloc(data, alloc_size, offset_ARRAY_ELEMENTS):c_ptr(eltType);
}
