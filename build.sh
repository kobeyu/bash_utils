#!/bin/bash

if [ ! -d $TRDPARTY_DIR ]; then
    echo "3rd party dir does not exist!"
    exit 1
fi

build_mode="build" #build or clean(remove build dir and rebuild again)
build_cores=$(($(nproc) / 2))

#############################
###### Build Functions ######
#############################
function CheckDir() {
    local dir=$1

    if [ ! -d $dir ]; then
        LogError "Dir $dir does not exist!"
        exit 1
    fi

}

function CheckFile() {
    local file=$1

    if [ ! -f $file ]; then
        LogError "File $file does not exist!"
        exit 1
    fi
}

function BuildGem5() {
    CheckDir $GEM5_DIR

    local build_dir=$GEM5_DIR/build
    if [ $build_mode == 'clean' ] || [ ! -d $build_dir ]; then
        LogNotice "Clean build GEM5"
        rm -rf $build_dir
    fi

    cd $GEM5_DIR
    scons build/RISCV/gem5.opt -j $build_cores
    cd - >/dev/null

    CheckFile $build_dir/RISCV/gem5.opt
}

function BuildRISCVGNUToolchain() {
    CheckDir $RISCV_GNU_DIR

    cd $RISCV_GNU_DIR

    if [ $build_mode == 'clean' ] || [ ! -f $RISCV_GNU_DIR/Makefile ]; then
        # TODO: Check how to clean build
        rm -rf $RISCV_GNU_DIR/Makefile
        rm -rf $RISCV_GNU_DIR/build*

        LogNotice "Clean build RISCV GNU Toolchain"
        ./configure --prefix=$RISCV
    fi

    make -j $build_cores

    CheckFile $RISCV/bin/riscv64-unknown-elf-gcc
}

function CreateSpikeBuildDir() {
    local build_dir=$1
    mkdir -p $build_dir
    cd $build_dir
    $SPIKE_DIR/configure --prefix=$RISCV
    cd - >/dev/null
}

function BuildSpike() {
    CheckDir $SPIKE_DIR

    local build_dir=$SPIKE_DIR/build

    if [ $build_mode == 'clean' ] || [ ! -d $build_dir ]; then
        rm -rf $build_dir
        CreateSpikeBuildDir $build_dir
    fi

    cd $build_dir
    make -j $build_cores
    make install

    CheckFile $build_dir/spike
}

function CreatePKBuildDir() {
    local build_dir=$1
    mkdir -p $build_dir
    cd $build_dir
    $PK_DIR/configure --prefix=$RISCV --host=riscv64-unknown-elf
    cd - >/dev/null

}

function BuildPK() {
    CheckDir $PK_DIR

    export PATH=$RISCV/bin:$PATH #for cross compile

    local build_dir=$PK_DIR/build

    if [ $build_mode == 'clean' ] || [ ! -d $build_dir ]; then
        rm -rf $build_dir
        CreatePKBuildDir $build_dir
    fi

    cd $build_dir
    make -j $build_cores
    make install

    CheckFile $build_dir/pk
}

function CreateLongRISCVLLVMBuildDir {
    build_dir=$1
    mkdir $build_dir
    cd $build_dir
    cmake -DLLVM_TARGETS_TO_BUILD="X86;Hexagon" \
        -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="LongRISCV" \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DCMAKE_BUILD_TYPE=Debug \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_USE_LINKER=gold \
        -G Ninja ../llvm/
    cd - >/dev/null
}

function BuildLongRISCVLLVM {
    CheckDir $LONGRISCV_LLVM_DIR

    local build_dir=$LONGRISCV_LLVM_DIR/build

    if [ $build_mode == 'clean' ] || [ ! -d $build_dir ]; then
        rm -rf $build_dir
        CreateLongRISCVLLVMBuildDir $build_dir
    fi

    cd $build_dir
    ninja -j $build_cores

    CheckFile $build_dir/bin/llvm-config
}

function CreateHalideBuildDir() {
    cd $HALIDE_DIR

    if [ ! -d $RISCV_LLVM_DIR ]; then
        echo "riscv llvm dir does not exist! $RISCV_LLVM_DIR"
        exit 1
    fi

    llvm_build_lib=$RISCV_LLVM_DIR/build/lib/cmake/llvm
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=install \
        -DCMAKE_BUILD_TYPE=Debug -DLLVM_DIR=$llvm_build_lib \
        -S . -B build
}

function BuildHalide() {
    CheckDir $HALIDE_DIR

    local build_dir=$HALIDE_DIR/build

    if [ $build_mode == 'clean' ] || [ ! -d $build_dir ]; then
        rm -rf $build_dir
        CreateHalideBuildDir $build_dir
    fi

    cd $build_dir

    ninja
    ninja install

    CheckFile $build_dir/src/libHalide.so
}
############
### MAIN ###
############

if [ -d ~/workspace/venv ]; then
    source ~/workspace/venv/bin/activate
fi
