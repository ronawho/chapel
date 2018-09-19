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

using namespace re2;
using namespace std;

int main(void)
{
    string str, out;
    int len1, len2;
    int read_size;
    char *buf;

    string pattern1[] = {
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

    string pattern2[] = {
        "tHa[Nt]", "<4>", "aND|caN|Ha[DS]|WaS", "<3>", "a[NSt]|BY", "<2>",
        "<[^>]*>", "|", "\\|[^|][^|]*\\|", "-"
    };


    fseek(stdin, 0, SEEK_END);
    read_size = ftell(stdin);

    buf = new char[read_size];
    rewind(stdin);
    read_size = fread(buf, 1, read_size, stdin);

    str.append(buf, read_size);

    delete [] buf;

    len1 = str.length();
    RE2::GlobalReplace(&str, ">.*\n|\n", "");
    len2 = str.length();

    out = str;

    {
        for (int i = 0; i < (int)(sizeof(pattern1) / sizeof(string)); i++) {
            int count = 0;
            RE2 pat(pattern1[i]);
            StringPiece piece = str;

            while (RE2::FindAndConsume(&piece, pat)) {
                count++;
            }

            cout << pattern1[i] << " " << count << endl;
        }

        for (int i = 0; i < (int)(sizeof(pattern2) / sizeof(string)); i += 2) {
            RE2::GlobalReplace(&out, pattern2[i], pattern2[i + 1]);
        }
    }

    cout << endl;
    cout << len1 << endl;
    cout << len2 << endl;
    cout << out.length() << endl;

}
