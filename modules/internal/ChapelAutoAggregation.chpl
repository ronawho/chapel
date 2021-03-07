/*
 * Copyright 2020-2021 Hewlett Packard Enterprise Development LP
 * Copyright 2004-2019 Cray Inc.
 * Other additional copyright holders may be indicated within.
 *
 * The entirety of this work is licensed under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module ChapelAutoAggregation {
  private use CopyAggregation;

  config param verboseAggregation = false;

  pragma "aggregator generator"
  proc chpl_srcAggregatorFor(arr: []) {
    return new SrcAggregator(arr.eltType);
  }

  // we can't do dom: domain here, it causes resolution issues
  pragma "aggregator generator"
  proc chpl_srcAggregatorFor(dom) where isDomain(dom) {
    return new SrcAggregator(dom.idxType);
  }

  pragma "aggregator generator"
  proc chpl_srcAggregatorFor(arr) {
    return nil;  // return type signals that we shouldn't aggregate
  }

  pragma "aggregator generator"
  proc chpl_dstAggregatorFor(arr: []) {
    return new DstAggregator(arr.eltType);
  }

  pragma "aggregator generator"
  proc chpl_dstAggregatorFor(dom) where isDomain(dom) {
    // this is only called if the user has:
    // 
    // forall i in myDomain { i = foo(); }
    //
    // We want that code to fail with proper error message, so we have this
    // function but return nil from it.
    return nil;
  }

  pragma "aggregator generator"
  proc chpl_dstAggregatorFor(arr) {
    return nil;  // return type signals that we shouldn't aggregate
  }

  proc chpl__arrayIteratorYieldsLocalElements(x) param {
    if isArray(x) {
      if !isClass(x.eltType) { // I have no idea if we can do this for wide pointers
        return x.iteratorYieldsLocalElements();
      }
    }
    else if isDomain(x) {
      return x.iteratorYieldsLocalElements();
    }
    return false;
  }

  // make sure to resolve this, so that we can give a more meaningful error
  // message
  proc chpl__arrayIteratorYieldsLocalElements(type a) param {
    return false;
  }

  module CopyAggregation {
    use SysCTypes;
    use CPtr;
    use AggregationPrimitives;
    use Time;
    record chpl_LocalSpinlock {
      var l: chpl__processorAtomicType(bool);
      inline proc tryLock() {
          return !l.read() && !l.testAndSet(memoryOrder.acquire);
      }
      inline proc lock() {
        while !this.tryLock() do chpl_task_yield();
      }
      inline proc unlock() {
        l.clear(memoryOrder.release);
      }
    }

    private const yieldFrequency = getEnvInt("CHPL_AGGREGATION_YIELD_FREQUENCY", 1024);
    private const yieldFrequency2 = getEnvInt("CHPL_AGGREGATION_YIELD_FREQUENCY2", 32);
    private const dstBuffSize = getEnvInt("CHPL_AGGREGATION_DST_BUFF_SIZE", 4096);
    private const srcBuffSize = getEnvInt("CHPL_AGGREGATION_SRC_BUFF_SIZE", 8192);
    private const localSrcBuffSize = getEnvInt("CHPL_AGGREGATION_LOCAL_SRC_BUFF_SIZE", 256);

    /*
     * Aggregates copy(ref dst, src). Optimized for when src is local.
     * Not parallel safe and is expected to be created on a per-task basis
     * High memory usage since there are per-destination buffers
     */
    record DstAggregator {
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

      inline proc copy(ref dst: elemType, const in srcVal: elemType) {
        if verboseAggregation {
          writeln("DstAggregator.copy is called");
        }
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
            dstAddr.deref() = srcVal;
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


    /*
     * Aggregates copy(ref dst, const ref src). Only works when dst is local.
     * Not parallel safe and is expected to be created on a per task basis
     * High memory usage since there are per-destination buffers
     */
    record LocalSrcAggregator {
      type elemType;
      type aggType = c_ptr(elemType);
      const bufferSize = localSrcBuffSize;
      const myLocaleSpace = LocaleSpace;
      var opsUntilYield = yieldFrequency;
      var dstAddrs: [myLocaleSpace][0..#bufferSize] aggType;
      var lSrcAddrs: [myLocaleSpace][0..#bufferSize] aggType;
      var bufferIdxs: [myLocaleSpace] int;
      var parents: unmanaged MultiSrcAggregator(elemType);

      proc deinit() {
        flush();
      }

      proc flush() {
        for loc in myLocaleSpace {
          _flushBuffer(loc, bufferIdxs[loc], freeData=true);
        }
      }

      inline proc copy(ref dst: elemType, const ref src: elemType) {
        const dstAddr = getAddr(dst);

        const loc = src.locale.id;
        const srcAddr = getAddr(src);

        ref bufferIdx = bufferIdxs[loc];
        lSrcAddrs[loc][bufferIdx] = srcAddr;
        dstAddrs[loc][bufferIdx] = dstAddr;
        bufferIdx += 1;

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

        var triesUntilYield = yieldFrequency2;
        var copied = false;
        while !copied {

          for parent in parents.aggs {
            if parent.lock.tryLock() {
              parent.copy(dstAddrs[loc], lSrcAddrs[loc], loc, myBufferIdx);
              parent.lock.unlock();
              copied = true;
              break;
            }
          }
          triesUntilYield -= 1;
          if triesUntilYield == 0 && !copied{
            chpl_task_yield();
            triesUntilYield = yieldFrequency2;
          }

        }
        bufferIdx = 0;
      }
    }

    class MultiSrcAggregator {
      type elemType;
      var numAggs: int;
      var aggs:[0..<numAggs] unmanaged SrcAggregator(elemType);

      proc init(type elemType, numAggs) {
        this.elemType = elemType;
        this.numAggs = numAggs;
        this.aggs = [0..<numAggs] new unmanaged SrcAggregator(elemType);
      }
      proc deinit() {
        for agg in aggs do delete agg;
      }
    }

    class SrcAggregator {
      type elemType;
      type aggType = c_ptr(elemType);
      const bufferSize = srcBuffSize;
      const myLocaleSpace = LocaleSpace;
      var opsUntilYield = yieldFrequency;
      var dstAddrs: [myLocaleSpace][0..#bufferSize] aggType;
      var lSrcAddrs: [myLocaleSpace][0..#bufferSize] aggType;
      var lSrcVals: [myLocaleSpace][0..#bufferSize] elemType;
      var rSrcAddrs: [myLocaleSpace] remoteBuffer(aggType);
      var rSrcVals: [myLocaleSpace] remoteBuffer(elemType);

      var bufferIdxs: [myLocaleSpace] int;
      var lock: chpl_LocalSpinlock;

      proc postinit() {
        for loc in myLocaleSpace {
          rSrcAddrs[loc] = new remoteBuffer(aggType, bufferSize, loc);
          rSrcVals[loc] = new remoteBuffer(elemType, bufferSize, loc);
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

      inline proc copy(dstAddr: [] aggType, srcAddr: [] aggType, loc: int, size: int) {

        ref bufferIdx = bufferIdxs[loc];
        // If there's not enough room in the buffer flush it (could partially
        // fill and flush later)
        if bufferSize - bufferIdx - size < 0 {
          _flushBuffer(loc, bufferIdx, freeData=false);
        }

        c_memcpy(c_ptrTo(lSrcAddrs[loc][bufferIdx]), c_ptrTo(srcAddr[0]), size*c_sizeof(aggType):int);
        c_memcpy(c_ptrTo(dstAddrs[loc][bufferIdx]), c_ptrTo(dstAddr[0]), size*c_sizeof(aggType):int);
        bufferIdx += size;

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

        ref myLSrcVals = lSrcVals[loc];
        ref myRSrcAddrs = rSrcAddrs[loc];
        ref myRSrcVals = rSrcVals[loc];

        // Allocate remote buffers
        const rSrcAddrPtr = myRSrcAddrs.cachedAlloc();
        const rSrcValPtr = myRSrcVals.cachedAlloc();

        // Copy local addresses to remote buffer
        myRSrcAddrs.PUT(lSrcAddrs[loc], myBufferIdx);

        // Process remote buffer, copying the value of our addresses into a
        // remote buffer
        on Locales[loc] {
          for i in 0..<myBufferIdx {
            rSrcValPtr[i] = rSrcAddrPtr[i].deref();
          }
          if freeData {
            myRSrcAddrs.localFree(rSrcAddrPtr);
          }
        }
        if freeData {
          myRSrcAddrs.markFreed();
        }

        // Copy remote values into local buffer
        myRSrcVals.GET(myLSrcVals, myBufferIdx);

        // Assign the srcVal to the dstAddrs
        var dstAddrPtr = c_ptrTo(dstAddrs[loc][0]);
        var srcValPtr = c_ptrTo(myLSrcVals[0]);
        for i in 0..<myBufferIdx {
          dstAddrPtr[i].deref() = srcValPtr[i];
        }

        bufferIdx = 0;
      }
    }

  }

  module AggregationPrimitives {
    use CPtr;
    use SysCTypes;

    inline proc getAddr(const ref p): c_ptr(p.type) {
      // TODO can this use c_ptrTo?
      return __primitive("_wide_get_addr", p): c_ptr(p.type);
    }

    inline proc GET(addr, node, rAddr, size) {
      __primitive("chpl_comm_get", addr, node, rAddr, size);
    }

    inline proc PUT(addr, node, rAddr, size) {
      __primitive("chpl_comm_put", addr, node, rAddr, size);
    }

    proc getEnvInt(name: string, default: int): int {
      extern proc getenv(name : c_string) : c_string;
      var strval = getenv(name.localize().c_str()): string;
      if strval.isEmpty() { return default; }
      return try! strval: int;
    }

    record remoteBuffer {
      type elemType;
      var size: int;
      var loc: int;
      var data: c_ptr(elemType);

      // Allocate a buffer on loc if we haven't already. Return a c_ptr to the
      // remote locales buffer
      proc cachedAlloc(): c_ptr(elemType) {
        if data == c_nil {
          const rvf_size = size;
          on Locales[loc] do {
            data = c_malloc(elemType, rvf_size);
          }
        }
        return data;
      }

      // Iterate through buffer elements, must be running on loc. data is passed
      // in to avoid communication.
      pragma "order independent yielding loops"
      iter localIter(data: c_ptr(elemType), size: int) ref : elemType {
        if boundsChecking {
          assert(this.loc == here.id);
          assert(this.data == data);
          assert(data != c_nil);
        }
        for i in 0..<size {
          yield data[i];
        }
      }

      // Free the data, must be running on the owning locale, data is passed in
      // to avoid communication. Data is freed'd automatically when this record
      // goes out of scope, but this is an optimization to free when already
      // running on loc
      inline proc localFree(data: c_ptr(elemType)) {
        if boundsChecking {
          assert(this.loc == here.id);
          assert(this.data == data);
          assert(data != c_nil);
        }
        c_free(data);
      }

      // After free'ing the data, need to nil out the records copy of the pointer
      // so we don't double-free on deinit
      inline proc markFreed() {
        if boundsChecking {
          assert(this.locale.id == here.id);
        }
        data = c_nil;
      }

      // Copy size elements from lArr to the remote buffer. Must be running on
      // lArr's locale.
      proc PUT(lArr: [] elemType, size: int) where lArr.isDefaultRectangular() {
        if boundsChecking {
          assert(size <= this.size);
          assert(this.size == lArr.size);
          assert(lArr.domain.low == 0);
          assert(lArr.locale.id == here.id);
        }
        const byte_size = size:size_t * c_sizeof(elemType);
        AggregationPrimitives.PUT(c_ptrTo(lArr[0]), loc, data, byte_size);
      }

      proc GET(lArr: [] elemType, size: int) where lArr.isDefaultRectangular() {
        if boundsChecking {
          assert(size <= this.size);
          assert(this.size == lArr.size);
          assert(lArr.domain.low == 0);
          assert(lArr.locale.id == here.id);
        }
        const byte_size = size:size_t * c_sizeof(elemType);
        AggregationPrimitives.GET(c_ptrTo(lArr[0]), loc, data, byte_size);
      }

      proc deinit() {
        if data != c_nil {
          const rvf_data=data;
          on Locales[loc] {
            localFree(rvf_data);
          }
          markFreed();
        }
      }
    }
  }
}
