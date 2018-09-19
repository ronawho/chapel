/* Code from:  https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/regexredux-gpp-1.html

   Compile with:
       export RE2_INSTALL=$(python get_re2_path.py) && \
       c++ -c -pipe -O3 -fomit-frame-pointer -march=native -std=c++14 -I$RE2_INSTALL/include regexredux.c++ -o regexredux.c++.o && \
       c++ regexredux.c++.o -o regexredux.gpp_run $RE2_INSTALL/lib/libre2.a -lpthread

   Run with:
       time -p ./regexredux.gpp_run 0 < regexredux-input5000000.txt
*/

/* The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   regex-dna program contributed by Alexey Zolotov
   without openmp, without assert
   converted from regex-dna program
*/

#include <re2/re2.h>
#include <iostream>
#include <stdio.h>
#include <chrono>

using namespace re2;
using namespace std;

static auto startTimer() {
  auto start = std::chrono::high_resolution_clock::now();
  return start;
}

static auto reportTimer = [](auto start, auto name) {
  auto finish = std::chrono::high_resolution_clock::now();
  std::chrono::duration<double> elapsed = finish - start;
  std::cout << "\t" << name << ": " << elapsed.count() << " s\n";
};

int main(void) {
    string variants[] = {
        "agggtaaa|tttaccct",
        "[cgt]gggtaaa|tttaccc[acg]",
        "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct",
        "agg[act]taaa|ttta[agt]cct",
        "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct",
        "agggta[cgt]a|t[acg]taccct",
        "agggtaa[cgt]|[acg]ttaccct"
    };

    string subst[] = {
        "tHa[Nt]", "<4>", "aND|caN|Ha[DS]|WaS", "<3>", "a[NSt]|BY", "<2>",
        "<[^>]*>", "|", "\\|[^|][^|]*\\|", "-"
    };


auto readTimer = startTimer();
    string data;
    fseek(stdin, 0, SEEK_END);
    int read_size = ftell(stdin);

    char *buf = new char[read_size];
    rewind(stdin);
    read_size = fread(buf, 1, read_size, stdin);

    data.append(buf, read_size); // create a string from the raw buffer read in

    delete [] buf;
reportTimer(readTimer, "init");

auto rmNewlineTimer = startTimer();
    int initLen = data.length();
    RE2::GlobalReplace(&data, ">.*\n|\n", ""); // remove newlines
reportTimer(rmNewlineTimer, "rm newline");


    string copy = data; // make a copy so we can perform replacements in parallel

    {
auto variantsTimer = startTimer();
        // count variants
        for (int i = 0; i < (int)(sizeof(variants) / sizeof(string)); i++) {
            int count = 0;
            RE2 pat(variants[i]);
            StringPiece piece = data;

            while (RE2::FindAndConsume(&piece, pat)) {
                count++;
            }

            cout << variants[i] << " " << count << endl;
        }
reportTimer(variantsTimer, "count variants");

auto replaceTimer = startTimer();
        // perform replacements
        for (int i = 0; i < (int)(sizeof(subst) / sizeof(string)); i += 2) {
            RE2::GlobalReplace(&copy, subst[i], subst[i + 1]);
        }
reportTimer(replaceTimer, "perform replacements");
    }

    cout << endl;
    cout << initLen << endl;
    cout << data.length() << endl;
    cout << copy.length() << endl;
}
