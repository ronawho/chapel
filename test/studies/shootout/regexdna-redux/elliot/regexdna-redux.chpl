/* Code from:  1.18 release regexdna-redux.chpl

   Compile with:
       chpl --fast regexdna-redux.chpl

   Run with:
       time -p ./regexdna-redux --n=0 < regexredux-input5000000.txt
*/



/* The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   regex-dna program contributed by Ben Harshbarger
   derived from the GNU C++ RE2 version by Alexey Zolotov
   converted from regex-dna program
*/








proc main(args: [] string) {
  var variants = [
    "agggtaaa|tttaccct",
    "[cgt]gggtaaa|tttaccc[acg]",
    "a[act]ggtaaa|tttacc[agt]t",
    "ag[act]gtaaa|tttac[agt]ct",
    "agg[act]taaa|ttta[agt]cct",
    "aggg[acg]aaa|ttt[cgt]ccct",
    "agggt[cgt]aa|tt[acg]accct",
    "agggta[cgt]a|t[acg]taccct",
    "agggtaa[cgt]|[acg]ttaccct"
  ];

  var subst = [
    ("tHa[Nt]", "<4>"), ("aND|caN|Ha[DS]|WaS", "<3>"), ("a[NSt]|BY", "<2>"),
    ("<[^>]*>", "|"), ("\\|[^|][^|]*\\|", "-")
  ];

  var data: string;








  stdin.readstring(data); // read in the entire file as a string



  const initLen = data.length;
  data = compile(">.*\n|\n").sub("", data); // remove newlines

  var copy = data; // make a copy so we can perform replacements in parallel

  {
    // count variants
    for variants in variants {
      var count = 0;



      for m in compile(variants).matches(data) {
        count += 1;
      }

      writeln(variants, " ", count);
    }

    // perform replacements
    for (f, r) in subst {
      copy = compile(f).sub(r, copy);
    }
  }

  writeln();
  writeln(initLen);
  writeln(data.length);
  writeln(copy.length);
}
