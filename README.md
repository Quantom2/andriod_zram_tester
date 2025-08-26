# Android Zram Benchmark
Complex Zram algorithms tester. Test your Zram algorithms to find best-implemented one for your kernel, set up bunch of testing conditions at once, and see results in a convinient CSV file! This is all-in-one tool. WIP...

# Requirements
```
Root acces
Termux
Latest FIO release
```

## Reqirements instalation
Assuming you installed Root and termux, for installing FIO run this in your termux:
```
pkg install root-repo
pkg update
pkg install fio
```

Script will handle PATCH by itself

# Usage
```
Usage: test_zram.sh [options]

ZRAM Benchmark Script
Runs fio benchmarks on /dev/block/zram0 with various compression algorithms,
read/write ratios, and buffer compressibility levels. Results are saved to CSV.

Options:
  -z, --zram-size <GB>         Total size of ZRAM device (default: 4).
                               Do NOT set larger than free RAM.

  -s, --size <GB>              Data size per test when using SIZE mode
                               (default: 128).

  -f, --file-size <GB>         Per-job file size to ensure fit in ZRAM
                               (default: 3).

  -w, --warmup-time <sec>      Warmup time before measurement (default: 30).

  -d, --duration <sec>         Test duration for TIME mode (default: 60).

  -r, --rw-ratio <N|N N ...>   Read/Write ratio in percent. Space separated list
                               Please use "" for passing lists
                               Example: "75" → 75% reads, 25% writes.
                               Example: "75 85" → run test two times with 75 and 85%
                               for each algorithm.

  -c, --compressnes-ratio <N|N N ...>
                               Data compressibility percentage.
                               Example: "25 35 45" (default: 25 35 45).
                               → run test three times with 25, 35 and 45%
                               compressness for each algorithm and R/W ratio.

  -t, --test-type <TIME|SIZE>  TIME → fixed duration (more data = better).
                               SIZE → fixed data amount (less time = better).
                               Note: SIZE mode has fio limitations.

  -e, --exclude-alg <list>     Space- or "|"-separated list of algorithms to skip.
                               Example: "lz4 zstd" or "lz4|zstd".

  -o, --only-alg <list>        Test only specific algorithms.
                               Same syntax as --exclude-alg.

  -out, --output <file>        Output CSV filename (default: zram_bench.csv).
                               File is saved to /sdcard/.

  -tmp, --tmppatch <dir>       Temporary working directory (default: /data/local/tmp/).

  -D, --debug                  Save raw fio output for each test in tmppatch.

  -h, --help                   Show this help and exit.

Output format:
  Results are written to CSV in the following structure:
    • Rows → different compression levels tested.
    • Columns → compression algorithms.
    • If multiple R/W ratios are specified, they are expanded across columns:
      Example of structure:
      ┌───────────────┬──────────────┬────────┬────────┬────────┐
      │               │ Compressness │  25%   │  35%   │   45%  │
      ├───────────────┼──────────────┼────────┼────────┼────────┤
      │               │ R/W ratio 75 │ Result │ Result │ Result │
      │ Algorithm 1   ├──────────────┼────────┼────────┼────────┤
      │               │ R/W ratio 85 │ Result │ Result │ Result │
      ├───────────────┼──────────────┼────────┼────────┼────────┤
      │               │ R/W ratio 75 │ Result │ Result │ Result │
      │ Algorithm 2   ├──────────────┼────────┼────────┼────────┤
      │               │ R/W ratio 85 │ Result │ Result │ Result │
      └───────────────┴──────────────┴────────┴────────┴────────┘
        • Rows = algorithms × R/W ratios
        • Columns = compressibility levels
        • Each cell = full set of collected metrics (bandwidth, IOPS, latency,
          CPU usage, memory stats, compression ratio, etc.)
        * In CSV file you see only [Result] blocks, Algorithm, R/W ratio and
          Compressness are written inside each one

    • Each algorithm testing result block contains detailed metrics:
      bandwidth, IOPS, latency (all with avg/min/max/stdev), CPU usage, memory usage,
      compressed/original sizes, and calculated ratios and bandwidth.
      All block have three main marks at the top left corner: algorithm, R/W ratio,
      compressness of data. All metrics is labled from left to right, from top to bottom.```
