#!/bin/bash
source ../lib.sh

HALIDE=$TRDPARTY_DIR/halide/install
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HALIDE/lib

function CompileHalideUtils()
{
    g++ -g main.cpp -std=c++17 \
        -ljpeg -lpng \
        -I$HALIDE/include -I$HALIDE/share/tools \
        -L $HALIDE/lib -lHalide \
        -o $exec
}



# Check the number of arguments
mode="$1"
path="$2"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <mode> <path>"
  echo "    [mode]: image2bin or bin2image"
  echo "    [path]: path to the file (png or binary)"
  exit 1
fi

# Extract the mode and path from arguments

# Check the mode and call the corresponding function
case "$mode" in
  "image2bin")
    ;;
  "bin2image")
    ;;
  *)
    echo "Error: Invalid mode. Supported modes are 'image2bin' and 'bin2image'."
    exit 1
    ;;
esac


exec=./halide_utils

if [ ! -f $exec ];then
    CompileHalideUtils
fi


$exec $mode $path
