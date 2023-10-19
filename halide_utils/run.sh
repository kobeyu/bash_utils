set -e

source ../lib.sh

TEST_DATA_DIR=$PROJECT_DIR/test_data/3dnr_input_images

for i in {1..8}; do
    echo "Iteration $i"
    ./halide_utils_wrapper.sh image2bin $TEST_DATA_DIR/noisy_sequence_0$i.png
    ./halide_utils_wrapper.sh bin2image $TEST_DATA_DIR/noisy_sequence_0$i.png_1920x1080.halide.bin
done


