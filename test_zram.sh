#!/system/bin/sh
export PATH=$PATH:/data/data/com.termux/files/usr/bin

how_to_use() {
    echo '
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
      compressness of data. All metrics is labled from left to right, from top to bottom.

Notes:
  - Requires fio to be installed in PATH.
  - Screen should be kept on during tests to avoid perfomance drops.
    '
    exit 1
}

# ZRAM Benchmark Script stock settings
JOBS=4                      # Number of separate FIO jobs
 ZRAM_TOTAL_SIZE=4           # Total size of ZRAM. Do NOT make it bigger than typycal amount of free RAM in youy device, GB
 WARMUP_TIME=30              # Warmup time, to ensure FIO fill disk with data before measuring algo perfomance, seconds
 SIZE=128                    # Size of block, BTW FIO don't work with it, GB
 DURATION=60                 # Duration of test if test is TIME based, seconds
 RATIOS='75'                 # Ratio between Read and Write. 75 means there would be 75% of Reads and 25% of Writes, %. Valid input: '[ratio] [ratio]'
 COMPRESSES='25 35 45'       # Compressness percentage of given data, %. Valid input: '[compressnes] [compressnes]'
 TEST_TYPE='TIME'            # Testing type. 'TIME' means time based (more data per similar time = better), when 'SIZE' means equal data for each algorithm (least time per same size = better). Although, 'SIZE' working incorrectly, because of FIO. Valid input: 'TIME' or 'SIZE'
 FILESIZE='3'                # Filesize used to restrict size FIO writes to, to ensure it will fit to ZRAM. As general rule, FILESIZE should be smaller than a ZRAM_TOTAL_SIZE (not equal, smaller!), GB
 OUTFILE="zram_bench.csv"    # Output file name. File will be placed to /sdcard/ to more aesy acsess afterwards
TMPPATCH="/data/local/tmp/" # Temporary work directory. Changing it is NOT recommended

#Optional settings that can be activated
#RATIOS='20 25 33 42 50 58 67 75 80'                            # Example of long and big test for large data comparison
#COMPRESSES='20 25 33 42 50 58 67 75 80'                        # Example of long and big test for large data comparison
#EXCLUDE_ALGS='deflate Izo Izo-rle'                             # This setting allows you to exclude certain algorithms from test. Valid input: '[algotirhm] [algorithm]' OR '[algotirhm]|[algorithm]'
#TEST_ONLY_ALGS='lz4 zstd lz4kd'                                # This setting allows you only test certain algorithms. Note that if algorithm doesn't present on your device, it won't be tested. Valid input: '[algotirhm] [algorithm]' OR '[algotirhm]|[algorithm]'
#THINKTIME=100                                                  # Allow to symulate pauses beetween inputs, although all my test just show that somewhy it breaks compression at all. Present in milisecons
#TEST_EXTRA_ARGS='--refill_buffers --buffer_compress_chunk=64K' # TEST_EXTRA_ARGS allows you to pass custom command arguments to FIO. This example enables re-filling buffers and make buffer compress chunk bigger (although, I founf no diffrence in result with or without this arguments)
#TEST_EXTRA_ARGS='--scramble_buffers=true'                      # Diffrent variation of previous example, scramble_buffers will not refill FIO buffers but slightly modify content so algorithm can not find multiple repeating pattern
#DEBUG='1'                                                      # If DEBUG is defined, script will save output of FIO as fio_{ALGORITHM}_rw_{RW_RATIO}_c_{COMPRESS}_result.txt in TMPPATCH/zram directory


# Startup argumets parsing
while [ $# -gt 0 ]; do
    case "$1" in
      -s|--size) shift; SIZE="$1" ;;
      -f|--file-size) shift; FILESIZE="$1" ;;
      -z|--zram-size) shift; ZRAM_TOTAL_SIZE="$1" ;;
      -w|--warmup-time) shift; WARMUP_TIME="$1" ;;
      -d|--duration) shift; DURATION="$1" ;;
      -r|--rw-ratio) shift; RATIOS="$1" ;;
      -c|--compressnes-ratio) shift; COMPRESSES="$1" ;;
      -t|--test-type) shift; TEST_TYPE="$1" ;;
      -e|--exclude-alg) shift; EXCLUDE_ALGS="$1" ;;
      -o|--only-alg) shift; TEST_ONLY_ALGS="$1" ;;
      -out|--output) shift; OUTFILE="$1" ;;
      -tmp|--tmppatch) shift; TMPPATCH="$1" ;;
      -D|--debug) DEBUG='1' ;;
      -h|--help) how_to_use ;;
      -*) echo "Unknown flag: $1 , script aborted"; exit 1 ;;
    esac
    shift
done

if [ -n "$TEST_ONLY_ALGS" ] && [ -n "$EXCLUDE_ALGS" ]; then
    echo 'Incorrect argumets!'
    how_to_use
fi

# setup CSV
echo " ; ; ; ; ; ; ; ; ; ;" > $OUTFILE

if [ "$TEST_TYPE" == "TIME" ] && [ -n "$THINKTIME" ] && [ "$THINKTIME" -gt 0 ]; then
    FIO_ARGS="--time_based --runtime=${DURATION}s --thinktime=${THINKTIME}ms"
elif [ "$TEST_TYPE" == "SIZE" ] && [ -n "$THINKTIME" ] && [ "$THINKTIME" -gt 0 ]; then
    FIO_ARGS="--size=${SIZE}G --write_bw_log=bw_log --write_lat_log=lat_log --write_iops_log=iops_log --thinktime=${THINKTIME}ms"
elif [ "$TEST_TYPE" == "TIME" ]; then
    FIO_ARGS="--time_based --runtime=${DURATION}s"
elif [ "$TEST_TYPE" == "SIZE" ]; then
    FIO_ARGS="--size=${SIZE}G --write_bw_log=bw_log --write_lat_log=lat_log --write_iops_log=iops_log"
else
    echo 'Incorrect argumets'
    how_to_use
fi

if [ -n "$TEST_EXTRA_ARGS" ]; then
    FIO_ARGS="$FIO_ARGS $TEST_EXTRA_ARGS"
fi

if [ -n "$FILESIZE" ]; then
    :
else
    FILESIZE=$((ZRAM_TOTAL_SIZE / JOBS))
fi

if [ -n "$DEBUG" ]; then
   rm -rf "$TMPPATCH/zram/"
   mkdir -p "$TMPPATCH/zram/"
fi

get_metric_multipyer() {
    UNIT=$(echo "$1" | grep -oE 'KiB|MiB|GiB' | tr -d '[:space:]')

    case "$UNIT" in
        "GiB")
            eval "$2_MULT=\$((1024 * 1024 * 1024))" ;;
        "MiB")
            eval "$2_MULT=\$((1024 * 1024))" ;;
        "KiB")
            eval "$2_MULT=1024" ;;
        "")
            eval "$2_MULT=1" ;;
        *)
            echo "[ERROR]: Cannot get multiplier!"; exit 1 ;;
    esac
}

get_lat_metric() {
    SEC=$(echo "$1" | grep 'sec' | sed 's/sec//' | tr -d '[:space:]')
    if [ -z "$SEC" ]; then
        eval "$2_MULT=1000000000"
    elif [ "$SEC" == "m" ]; then
        eval "$2_MULT=1000000"
    elif [ "$SEC" == "u" ]; then
        eval "$2_MULT=1000"
    elif [ "$SEC" == "n" ]; then
        eval "$2_MULT=1"
    else
        echo "[ERROR]: Cannot get multiplyer!"; exit 1
    fi
}

run_test() {
    ALG=$1
    EXTRA_ARGS="$2"

    echo ">>> Testing $ALG. R/W ratio: $RW_RATIO. Compresity: $COMPRESS %"

    # Reset zram
    echo 1 > /sys/block/zram0/reset
    sleep 3
    echo 0 > /sys/block/zram0/disksize
    sleep 2

    if [ "$CHANGE_ALG" == "1" ]; then
        echo $ALG > /sys/block/zram0/comp_algorithm
        unset CHANGE_ALG
    fi

    # Check if algo matches reqired
    CURR_ARG=$(cat /sys/block/zram0/comp_algorithm | tr ' ' '\n' | grep -E '\[|\]' | tr -d '[]')
    ERR=0

    while [ "$CURR_ARG" != "$ALG" ]; do
        swapoff /dev/block/zram0 2>/dev/null
        if [ "$ERR" -eq 3 ]; then
            echo ">>> Algorithm setip failed 3 times! Exiting..."
            exit 1
        fi
        echo $ALG > /sys/block/zram0/comp_algorithm
        ERR=$((ERR + 1))
        echo "[WARNING] Algorithm setip failed $ERR times!"
        sleep 2
    done
    unset ERR

    echo ${ZRAM_TOTAL_SIZE}G > /sys/block/zram0/disksize

    # Test if algo running
    echo ">>> Current algo check: [$(cat /sys/block/zram0/comp_algorithm | tr ' ' '\n' | grep -E '\[|\]' | tr -d '[]')]"
    sleep 10

    # Print TIME for user and save it for later
    echo "[TIME]: $(date "+%H:%M:%S") <<< TEST STARTED"
    START_TIME=$(date +%s)

    # CPU usage baseline
    CPU_BEFORE=$(awk '/cpu / {print $2+$4}' /proc/stat)

    # Stress ZRAM (r/w swap) --refill_buffers
    FIO_OUT=$(fio --name=zramtest --filename=/dev/block/zram0 --rw=randrw --bs=4k --iodepth=1 --numjobs=${JOBS} --filesize=${FILESIZE}G ${FIO_ARGS} --ramp_time=${WARMUP_TIME}s --group_reporting --eta=never --log_avg_msec=200 ${EXTRA_ARGS}) # 2>/dev/null

    # CPU usage after
    CPU_AFTER=$(awk '/cpu / {print $2+$4}' /proc/stat)

    # Print TIME for user and save it for later
    FINISH_TIME=$(date +%s)
    echo "[TIME]: $(date "+%H:%M:%S") <<< TEST FINISED"

    #Calculate CPU and TIME deltas
    CPU_DELTA=$((CPU_AFTER - CPU_BEFORE))
    TIME_DELTA=$((FINISH_TIME - START_TIME))

    # Get stats
    # From zram on device
    STATS=$(cat /sys/block/zram0/mm_stat)
    ORIG="$(echo $STATS | awk '{print $1}')"
    COMP="$(echo $STATS | awk '{print $2}')"
    MEM_TOTAL=$(echo $STATS | awk '{print $3}')
    MEM_MAX=$(echo $STATS | awk '{print $5}')
    RATIO=0
    if [ "$COMP" -gt 0 ]; then
        RATIO_TMP=$(echo "$ORIG / $COMP" | bc -l)
        RATIO=$(printf "%.9f\n" "$RATIO_TMP")
    fi

    # from fio
    BW_READ_SHORT=$(echo "$FIO_OUT" | grep "READ:" | awk -F'[,= ]+' '{print $4}')   # MB/s
    BW_WRITE_SHORT=$(echo "$FIO_OUT" | grep "WRITE:" | awk -F'[,= ]+' '{print $4}') # MB/s

    BW_READ=$(echo "$FIO_OUT" | grep "bw " | sed '2d' | tr ',|:|(|)' '\n')
    BW_WRITE=$(echo "$FIO_OUT" | grep "bw " | sed '1d' | tr ',|:|(|)' '\n')

    BW_READ_MIN=$(echo "$BW_READ" | grep "min" | cut -d= -f2 )
    BW_READ_MAX=$(echo "$BW_READ" | grep "max" | cut -d= -f2 )
    BW_READ_AVG=$(echo "$BW_READ" | grep "avg" | cut -d= -f2 )
    BW_READ_STDEV=$(echo "$BW_READ" | grep "stdev" | cut -d= -f2 )

    BW_WRITE_MIN=$(echo "$BW_WRITE" | grep "min" | cut -d= -f2 )
    BW_WRITE_MAX=$(echo "$BW_WRITE" | grep "max" | cut -d= -f2 )
    BW_WRITE_AVG=$(echo "$BW_WRITE" | grep "avg" | cut -d= -f2 )
    BW_WRITE_STDEV=$(echo "$BW_WRITE" | grep "stdev" | cut -d= -f2 )

    get_metric_multipyer "$BW_READ" "BW_READ"
    get_metric_multipyer "$BW_WRITE" "BW_WRITE"

    BW_READ_MIN=$(echo "$BW_READ_MIN * $BW_READ_MULT" | bc)
    BW_READ_MAX=$(echo "$BW_READ_MAX * $BW_READ_MULT" | bc)
    BW_READ_AVG=$(echo "$BW_READ_AVG * $BW_READ_MULT" | bc)
    BW_READ_STDEV=$(echo "$BW_READ_STDEV * $BW_READ_MULT" | bc)

    BW_WRITE_MIN=$(echo "$BW_WRITE_MIN * $BW_WRITE_MULT" | bc)
    BW_WRITE_MAX=$(echo "$BW_WRITE_MAX * $BW_WRITE_MULT" | bc)
    BW_WRITE_AVG=$(echo "$BW_WRITE_AVG * $BW_WRITE_MULT" | bc)
    BW_WRITE_STDEV=$(echo "$BW_WRITE_STDEV * $BW_WRITE_MULT" | bc)

    IOPS_READ_SHORT=$(echo "$FIO_OUT" | grep "IOPS=" | awk -F'[=, ]+' '{print $4}' | sed '2d')
    IOPS_WRITE_SHORT=$(echo "$FIO_OUT" | grep "IOPS=" | awk -F'[=, ]+' '{print $4}' | sed '1d')

    IOPS_READ=$(echo "$FIO_OUT" | grep "iops" | sed '2d' | tr ',|:|(|)' '\n')
    IOPS_WRITE=$(echo "$FIO_OUT" | grep "iops" | sed '1d' | tr ',|:|(|)' '\n')

    IOPS_READ_MIN=$(echo "$IOPS_READ" | grep "min" | cut -d= -f2 )
    IOPS_READ_MAX=$(echo "$IOPS_READ" | grep "max" | cut -d= -f2 )
    IOPS_READ_AVG=$(echo "$IOPS_READ" | grep "avg" | cut -d= -f2 )
    IOPS_READ_STDEV=$(echo "$IOPS_READ" | grep "stdev" | cut -d= -f2 )

    IOPS_WRITE_MIN=$(echo "$IOPS_WRITE" | grep "min" | cut -d= -f2 )
    IOPS_WRITE_MAX=$(echo "$IOPS_WRITE" | grep "max" | cut -d= -f2 )
    IOPS_WRITE_AVG=$(echo "$IOPS_WRITE" | grep "avg" | cut -d= -f2 )
    IOPS_WRITE_STDEV=$(echo "$IOPS_WRITE" | grep "stdev" | cut -d= -f2 )

    CLAT_READ=$(echo "$FIO_OUT" | grep 'clat' | grep -E 'min|max|avg|stdev' | sed '2d' | tr ',|:|(|)' '\n')  # avg latency
    CLAT_WRITE=$(echo "$FIO_OUT" | grep 'clat' | grep -E 'min|max|avg|stdev' | sed '1d' | tr ',|:|(|)' '\n') # avg latency

    CLAT_READ_MIN=$(echo "$CLAT_READ" | grep "min" | cut -d= -f2 | sed 's#k#*1000#')
    CLAT_READ_MAX=$(echo "$CLAT_READ" | grep "max" | cut -d= -f2 | sed 's#k#*1000#' )
    CLAT_READ_AVG=$(echo "$CLAT_READ" | grep "avg" | cut -d= -f2 | sed 's#k#*1000#')
    CLAT_READ_STDEV=$(echo "$CLAT_READ" | grep "stdev" | cut -d= -f2 | sed 's#k#*1000#')

    CLAT_WRITE_MIN=$(echo "$CLAT_WRITE" | grep "min" | cut -d= -f2 | sed 's#k#*1000#')
    CLAT_WRITE_MAX=$(echo "$CLAT_WRITE" | grep "max" | cut -d= -f2 | sed 's#k#*1000#')
    CLAT_WRITE_AVG=$(echo "$CLAT_WRITE" | grep "avg" | cut -d= -f2 | sed 's#k#*1000#')
    CLAT_WRITE_STDEV=$(echo "$CLAT_WRITE" | grep "stdev" | cut -d= -f2 | sed 's#k#*1000#')

    get_lat_metric "$CLAT_READ" "CLAT_READ"
    get_lat_metric "$CLAT_WRITE" "CLAT_WRITE"

    CLAT_READ_MIN=$(echo "$CLAT_READ_MIN * $CLAT_READ_MULT" | bc)
    CLAT_READ_MAX=$(echo "$CLAT_READ_MAX * $CLAT_READ_MULT" | bc)
    CLAT_READ_AVG=$(echo "$CLAT_READ_AVG * $CLAT_READ_MULT" | bc)
    CLAT_READ_STDEV=$(echo "$CLAT_READ_STDEV * $CLAT_READ_MULT" | bc)

    CLAT_WRITE_MIN=$(echo "$CLAT_WRITE_MIN * $CLAT_WRITE_MULT" | bc)
    CLAT_WRITE_MAX=$(echo "$CLAT_WRITE_MAX * $CLAT_WRITE_MULT" | bc)
    CLAT_WRITE_AVG=$(echo "$CLAT_WRITE_AVG * $CLAT_WRITE_MULT" | bc)
    CLAT_WRITE_STDEV=$(echo "$CLAT_WRITE_STDEV * $CLAT_WRITE_MULT" | bc)

    LAT_READ=$(echo "$FIO_OUT" | grep ' lat' | grep -E 'min|max|avg|stdev' | sed '2d' | tr ',|:|(|)' '\n')  # avg latency
    LAT_WRITE=$(echo "$FIO_OUT" | grep ' lat' | grep -E 'min|max|avg|stdev' | sed '1d' | tr ',|:|(|)' '\n') # avg latency

    LAT_READ_MIN=$(echo "$LAT_READ" | grep "min" | cut -d= -f2 | sed 's#k#*1000#')
    LAT_READ_MAX=$(echo "$LAT_READ" | grep "max" | cut -d= -f2 | sed 's#k#*1000#')
    LAT_READ_AVG=$(echo "$LAT_READ" | grep "avg" | cut -d= -f2 | sed 's#k#*1000#')
    LAT_READ_STDEV=$(echo "$LAT_READ" | grep "stdev" | cut -d= -f2 | sed 's#k#*1000#')

    LAT_WRITE_MIN=$(echo "$LAT_WRITE" | grep "min" | cut -d= -f2 | sed 's#k#*1000#')
    LAT_WRITE_MAX=$(echo "$LAT_WRITE" | grep "max" | cut -d= -f2 | sed 's#k#*1000#')
    LAT_WRITE_AVG=$(echo "$LAT_WRITE" | grep "avg" | cut -d= -f2 | sed 's#k#*1000#')
    LAT_WRITE_STDEV=$(echo "$LAT_WRITE" | grep "stdev" | cut -d= -f2 | sed 's#k#*1000#')

    get_lat_metric "$LAT_READ" "LAT_READ"
    get_lat_metric "$LAT_WRITE" "LAT_WRITE"

    LAT_READ_MIN=$(echo "$LAT_READ_MIN * $LAT_READ_MULT" | bc)
    LAT_READ_MAX=$(echo "$LAT_READ_MAX * $LAT_READ_MULT" | bc)
    LAT_READ_AVG=$(echo "$LAT_READ_AVG * $LAT_READ_MULT" | bc)
    LAT_READ_STDEV=$(echo "$LAT_READ_STDEV * $LAT_READ_MULT" | bc)

    LAT_WRITE_MIN=$(echo "$LAT_WRITE_MIN * $LAT_WRITE_MULT" | bc)
    LAT_WRITE_MAX=$(echo "$LAT_WRITE_MAX * $LAT_WRITE_MULT" | bc)
    LAT_WRITE_AVG=$(echo "$LAT_WRITE_AVG * $LAT_WRITE_MULT" | bc)
    LAT_WRITE_STDEV=$(echo "$LAT_WRITE_STDEV * $LAT_WRITE_MULT" | bc)

    CPU_SYS=$(echo "$FIO_OUT" | grep "cpu" | awk -F'[=,% ]+' '{print $7}')
    CPU_USR=$(echo "$FIO_OUT" | grep "cpu" | awk -F'[=,% ]+' '{print $5}')

    TIME_READ=$(echo "$FIO_OUT" | grep "READ:" | awk -F'[,= ]+' '{print $12}' | cut -d- -f1)   # Time, msec
    TIME_WRITE=$(echo "$FIO_OUT" | grep "WRITE:" | awk -F'[,= ]+' '{print $12}' | cut -d- -f1) # Time, msec

    SIZE_READ=$(echo "$FIO_OUT" | grep "READ:" | awk -F'[,= ]+' '{print $9}' | cut -d- -f1)
    SIZE_WRITE=$(echo "$FIO_OUT" | grep "WRITE:" | awk -F'[,= ]+' '{print $9}' | cut -d- -f1)

    get_metric_multipyer "$SIZE_READ" "SIZE_READ"
    get_metric_multipyer "$SIZE_WRITE" "SIZE_WRITE"

    SIZE_READ_TEMP=$(echo "($SIZE_READ * $SIZE_READ_MULT) / (1024 * 1024 * 1024)" | sed 's/GiB//; s/MiB//; s/KiB//' | bc -l )
    SIZE_WRITE_TEMP=$(echo "($SIZE_WRITE * $SIZE_WRITE_MULT) / (1024 * 1024 * 1024)" | sed 's/GiB//; s/MiB//; s/KiB//' | bc -l )

    SIZE_READ=$(printf "%.9f\n" "$SIZE_READ_TEMP")
    SIZE_WRITE=$(printf "%.9f\n" "$SIZE_WRITE_TEMP")

    SIZE_TOTAL=$(echo "($SIZE_READ + $SIZE_WRITE)" | bc -l )

    SIZE_TOTAL=$(printf "%.9f\n" "$SIZE_TOTAL")

    BW_READ_CALC=$(echo "$SIZE_READ / $TIME_DELTA" |  bc -l )
    BW_WRITE_CALC=$(echo "$SIZE_WRITE / $TIME_DELTA" |  bc -l )

    BW_READ_CALC=$(printf "%.9f\n" "$BW_READ_CALC")
    BW_WRITE_CALC=$(printf "%.9f\n" "$BW_WRITE_CALC")

    # Save log to CSV
    LINE0="$LINE0 $ALG; R/W ratio:; $RW_RATIO; Compressness:; $COMPRESS; CPU cycle:; $CPU_DELTA; Compress ratio:; $RATIO; ;"
    LINE1="$LINE1 ; CPU use SYS; $CPU_SYS; CPU use USR; $CPU_USR; Real RAM used; $MEM_TOTAL; Peak RAM used; $MEM_MAX; ;"
    LINE2="$LINE2 Read:; $BW_READ_SHORT; IOPS:; $IOPS_READ_SHORT; Write:; $BW_WRITE_SHORT; IOPS:; $IOPS_WRITE_SHORT; ; Details below:;"
    LINE3="$LINE3 Read:; Avereage; Minimum; Maximum; STDEV; Write:; Avereage; Minimum; Maximum; STDEV;"
    LINE4="$LINE4 Latency (1); $CLAT_READ_AVG; $CLAT_READ_MIN; $CLAT_READ_MAX; $CLAT_READ_STDEV; Latency (1); $CLAT_WRITE_AVG; $CLAT_WRITE_MIN; $CLAT_WRITE_MAX; $CLAT_WRITE_STDEV;"
    LINE5="$LINE5 Latency (2); $LAT_READ_AVG; $LAT_READ_MIN; $LAT_READ_MAX; $LAT_READ_STDEV; Latency (2); $LAT_WRITE_AVG; $LAT_WRITE_MIN; $LAT_WRITE_MAX; $LAT_WRITE_STDEV;"
    LINE6="$LINE6 IOPS (detail); $IOPS_READ_AVG; $IOPS_READ_MIN; $IOPS_READ_MAX; $IOPS_READ_STDEV; IOPS (detail); $IOPS_WRITE_AVG; $IOPS_WRITE_MIN; $IOPS_WRITE_MAX; $IOPS_WRITE_STDEV;"
    LINE7="$LINE7 BW rate; $BW_READ_AVG; $BW_READ_MIN; $BW_READ_MAX; $BW_READ_STDEV; BW rate; $BW_WRITE_AVG; $BW_WRITE_MIN; $BW_WRITE_MAX; $BW_WRITE_STDEV;"
    LINE8="$LINE8 Time; (real) $TIME_DELTA; (READ) $TIME_READ; (WRITE) $TIME_WRITE; ; BW Calc (READ); $BW_READ_CALC GiB/s; Original size; $ORIG; ;"
    LINE9="$LINE9 Data; (total) $SIZE_TOTAL GiB; (READ) $SIZE_READ GiB; (WRITE) $SIZE_WRITE GiB; ; BW Calc (WRITE); $BW_WRITE_CALC GiB/s; Compressed size; $COMP; ;"

    if [ -n "$DEBUG" ]; then
        FILENAME="$TMPPATCH/zram/fio_${ALG}_rw_${RW_RATIO}_c_${COMPRESS}_result.txt"
        echo "<<< Saving FIO output to file: $FILENAME"
        echo "$FIO_OUT" > $FILENAME
    fi
}

swapoff /dev/block/zram0 2>/dev/null

cd "$TMPPATCH" # Make sure we don't flood system with waste

ALGS="$(cat /sys/block/zram0/comp_algorithm | tr -d '[]')"
echo "Supported Algorithms for your device:"
echo "$ALGS"

if [ -n "$EXCLUDE_ALGS" ]; then
    echo "Excluding specified Algorithm: $EXCLUDE_ALGS"
    EXCLUDE_ALGS="$(echo $EXCLUDE_ALGS | tr ' ' '|')" # Make sure algs in Extended regexp format: lz4|Izo|deflate, etc
    ALGS="$(echo $ALGS | tr ' ' '\n' | grep -Evx $EXCLUDE_ALGS | tr '\n' ' ')"
fi

if [ -n "$TEST_ONLY_ALGS" ]; then
    echo "Enabling only specified Algorithms: $TEST_ONLY_ALGS"
    TEST_ONLY_ALGS="$(echo $TEST_ONLY_ALGS | tr ' ' '|')" # Make sure algs in Extended regexp format: lz4|Izo|deflate, etc
    ALGS="$(echo $ALGS | tr ' ' '\n' | grep -Ex $TEST_ONLY_ALGS | tr '\n' ' ')"
fi
echo ">>> Testing Algorithms: $ALGS"

echo "[ATTENTION] It is recommended to start app to leave screen ON and don't touch phone for not interfearing results. You have 20 seconds to do that"
sleep 20

# --- Main cycle ---

for ALG in $ALGS; do
    CHANGE_ALG='1'
    for RW_RATIO in $RATIOS; do
        for COMPRESS in $COMPRESSES; do
            EXTRA_ARGS="--rwmixread=${RW_RATIO} --buffer_compress_percentage=${COMPRESS}"
            run_test "$ALG" "$EXTRA_ARGS"
            echo "Rest time after test!"
            sleep 10
        done
        # Save final log line to CSV
        echo "$LINE0" >> $OUTFILE
        echo "$LINE1" >> $OUTFILE
        echo "$LINE2" >> $OUTFILE
        echo "$LINE3" >> $OUTFILE
        echo "$LINE4" >> $OUTFILE
        echo "$LINE5" >> $OUTFILE
        echo "$LINE6" >> $OUTFILE
        echo "$LINE7" >> $OUTFILE
        echo "$LINE8" >> $OUTFILE
        echo "$LINE9" >> $OUTFILE
        unset LINE0 LINE1 LINE2 LINE3 LINE4 LINE5 LINE6 LINE7 LINE8 LINE9
        sleep 5
    done
    sleep 5
done

mv "$TMPPATCH/$OUTFILE" "/sdcard/$OUTFILE"

echo "✅ Done. Results saved in $OUTFILE"
