#!/bin/bash
RUNNER_LABEL="${RUNNER_LABEL:-AVX512-ICX}"
RUNNER="${RUNNER:-./rabbitRunner-${RUNNER_LABEL}}"
INPUT="./RabbitInput/RabbitInput.rct"
GEOMETRY="./RabbitInput/RabbitGeometry.rct"
VARIANT="LolaOMP"
BUFFER_SIZE="${BUFFER_SIZE:-1}"
SIZE=""
NUM_PROC=""
VOLOUT=""
export OMP_STACKSIZE="${OMP_STACKSIZE:-64M}"
usage() {
    echo "Usage: $0 -s <size> [-v <variant>] [-n <numProc>] [-o <outfile>] [-b <buffer>]"
    echo "  -s <size>      Problem size: 128, 256, 512, 1024"
    echo "  -v <variant>   Algorithm variant: LolaOMP, LolaBunny, LolaOPT, LolaASM, LolaISPC"
    echo "  -n <numProc>   Number of processors for likwid-pin optional"
    echo "  -o <outfile>   Output volume file optional"
    echo "  -b <buffer>    Projection buffer size default: ${BUFFER_SIZE}"
    exit 1
}
while getopts "s:v:n:o:b:h" opt; do
    case $opt in
        s) SIZE="$OPTARG" ;;
        v) VARIANT="$OPTARG" ;;
        n) NUM_PROC="$OPTARG" ;;
        o) VOLOUT="$OPTARG" ;;
        b) BUFFER_SIZE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
if [ -z "$SIZE" ]; then echo "Error: -s <size> is required"; usage; fi
if [ ! -x "$RUNNER" ]; then echo "Error: Runner not found: $RUNNER"; echo "Build with: make TOOLCHAIN=ICX SIMD=AVX512 ENABLE_OPENMP=true ENABLE_LIKWID=true ENABLE_ISPC=false"; exit 1; fi
REFVOL="./RabbitInput/Reference${SIZE}.vol"
CMD=( "$RUNNER" -b "$BUFFER_SIZE" -m "$VARIANT" -a "$GEOMETRY" -i "$INPUT" -s "$SIZE" )
if [ -f "$REFVOL" ]; then CMD+=( -c "$REFVOL" ); fi
if [ -n "$VOLOUT" ]; then CMD+=( -o "$VOLOUT" ); fi
if [ -n "$NUM_PROC" ]; then PIN="${PIN:-likwid-pin}"; echo "$PIN -c N:0-${NUM_PROC} ${CMD[*]}"; exec "$PIN" -c "N:0-${NUM_PROC}" "${CMD[@]}"; fi
echo "${CMD[*]}"
exec "${CMD[@]}"
