module AddAggregation {
  use AggregationPrimitives;
  use CPtr;

  private const yieldFrequency = getEnvInt("CHPL_AGGREGATION_YIELD_FREQUENCY", 1024);
  private const dstBuffSize = getEnvInt("CHPL_AGGREGATION_DST_BUFF_SIZE", 4096);

  /*
   * Aggregates add(ref dst, src). Optimized for when src is local. Not
   * parallel safe and is expected to be created on a per-task basis. Updates
   * to `dst` are  non-atomic. High memory usage since there are
   * per-destination buffers
   */
  record DstAddAggregator {
    type elemType;
    type aggType = (c_ptr(elemType), elemType);
    const bufferSize = dstBuffSize;
    const myLocaleSpace = LocaleSpace;
    var opsUntilYield = yieldFrequency;
    var lBuffers: [myLocaleSpace] [0..#bufferSize] aggType;
    var rBuffers: [myLocaleSpace] remoteBuffer(aggType);
    var bufferIdxs: [myLocaleSpace] int;

    proc postinit() {
      for loc in myLocaleSpace {
        rBuffers[loc] = new remoteBuffer(aggType, bufferSize, loc);
      }
    }

    proc deinit() {
      flush();
    }

    proc flush() {
      for loc in myLocaleSpace {
        _flushBuffer(loc, bufferIdxs[loc], freeData=true);
      }
    }

    inline proc add(ref dst: elemType, const in srcVal: elemType) {
      // Get the locale of dst and the local address on that locale
      const loc = dst.locale.id;
      const dstAddr = getAddr(dst);

      // Get our current index into the buffer for dst's locale
      ref bufferIdx = bufferIdxs[loc];

      // Buffer the address and desired value
      lBuffers[loc][bufferIdx] = (dstAddr, srcVal);
      bufferIdx += 1;

      // Flush our buffer if it's full. If it's been a while since we've let
      // other tasks run, yield so that we're not blocking remote tasks from
      // flushing their buffers.
      if bufferIdx == bufferSize {
        _flushBuffer(loc, bufferIdx, freeData=false);
        opsUntilYield = yieldFrequency;
      } else if opsUntilYield == 0 {
        chpl_task_yield();
        opsUntilYield = yieldFrequency;
      } else {
        opsUntilYield -= 1;
      }
    }

    proc _flushBuffer(loc: int, ref bufferIdx, freeData) {
      const myBufferIdx = bufferIdx;
      if myBufferIdx == 0 then return;

      // Allocate a remote buffer
      ref rBuffer = rBuffers[loc];
      const remBufferPtr = rBuffer.cachedAlloc();

      // Copy local buffer to remote buffer
      rBuffer.PUT(lBuffers[loc], myBufferIdx);

      // Process remote buffer
      on Locales[loc] {
        for (dstAddr, srcVal) in rBuffer.localIter(remBufferPtr, myBufferIdx) {
          dstAddr.deref() += srcVal;
        }
        if freeData {
          rBuffer.localFree(remBufferPtr);
        }
      }
      if freeData {
        rBuffer.markFreed();
      }
      bufferIdx = 0;
    }
  }
}
