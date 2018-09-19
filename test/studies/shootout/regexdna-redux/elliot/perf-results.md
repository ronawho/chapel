Performance results for nearly identical serial re2-based C++ and Chapel codes.
`C++ time` is using Chapel's version of re2, `sys C++ time` is using a system
install. All results gathered on shootout-like box.

| step            | C++ time  | sys C++ time  | Chpl time |
| --------------- | --------- | ------------- | --------- |
| init            |  0.11s    |  0.11s        |  1.48s    |
| rm newline      |  0.87s    |  0.75s        |  1.02s    |
| count variants  |  3.31s    |  2.80s        |  3.32s    |
| do replacements |  5.08s    |  4.89s        |  5.92s    |
|                 |           |               |           |
| above total     |  9.37s    |  8.55s        | 11.74s    |
| time -p total   |  9.42s    |  8.62s        | 11.82s    |

C++ code is from the shootout site and was slightly modified to match chapel
style for easier diffing, but code is identical. Timing from the site is 8.71s
(vs 8.62s for similar run on our machine.)

https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/regexredux-gpp-1.html


Perf notes:
-----------

With both Chapel and C++ using our re2 -- we're behind by ~2.5s. 1.25s of this
is spent reading the input. The rest of the time is overhead for removing
newlines ands doing the replacements. I would guess this is overhead because of
doing copies instead of in-place replacement.

Using our re2 also adds overhead. This is because of how we're building re2.
Under gcc 7 we end up throwing `-fno-ipa-cp-clone`, which hurts re2
performance. If I remove that I see better performance (C++ on par with sys
version, and chpl down at 10.92s.) Note that `-fno-ipa-cp-clone` is only thrown
for gcc 7. It was added in https://github.com/chapel-lang/chapel/pull/9481 to
help avoid correctness issues we saw with gcc 7. We actually saw the regression
on the shootout box, but it went in on May 8 when the shootout box was offline:
https://chapel-lang.org/perf/shootout/?startdate=2018/03/08&enddate=2018/09/19&graphs=regexdnareduxshootoutbenchmark

Note that when Issac upgrades to Chapel 1.18, we will see a performance drop.
We could special case so we don't throw `-fno-ipa-cp-clone` for third-party
code, but we had a pretty bad experience with gcc 7 in general, especially
without that flag. I suggest we just wait for the next ubuntu/gcc upgrade.
18.10 will be out in October and it is slated to have gcc 8.1:
https://www.phoronix.com/scan.php?page=news_item&px=Ubuntu-18.10-Compiler-Tooling


How to reproduce:
-----------------

C++ with Chapel's re2 (`C++ time`) instructions:
```sh
export RE2_INSTALL=$(python get_re2_path.py) && \
c++ -c -pipe -O3 -fomit-frame-pointer -march=native -std=c++14 -I$RE2_INSTALL/include regexredux.c++ -o regexredux.c++.o && \
c++ regexredux.c++.o -o regexredux.gpp_run $RE2_INSTALL/lib/libre2.a -lpthread

time -p ./regexredux.gpp_run 0 < regexredux-input5000000.txt
```

C++ with system re2 (`sys C++ time`) instructions:
```sh
c++ -c -pipe -O3 -fomit-frame-pointer -march=native -std=c++14 -I/usr/include/re2 regexredux.c++ -o regexredux.c++.o && \
c++ regexredux.c++.o -o regexredux.gpp_run /usr/lib/x86_64-linux-gnu/libre2.a -lpthread

time -p ./regexredux.gpp_run 0 < regexredux-input5000000.txt
```

Chapel instructions:
```sh
chpl --fast regexdna-redux.chpl

time -p ./regexdna-redux --n=0 < regexredux-input5000000.txt
```
