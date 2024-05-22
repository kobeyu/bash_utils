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


function BuildRISCVGNUToolchain() {
    CheckDir $RISCV_GNU_DIR

    cd $RISCV_GNU_DIR

    if [ "$build_mode" == 'clean' ] || [ ! -f $RISCV_GNU_DIR/Makefile ]; then
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

    if [ "$build_mode" == 'clean' ] || [ ! -d $build_dir ]; then
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

    CheckDir $RISCV

    #ref: https://github.com/riscv-software-src/riscv-pk/issues/298
    $PK_DIR/configure --prefix=$RISCV --host=riscv64-unknown-elf --with-arch=rv64gc_zifencei
    cd - >/dev/null

}

function BuildPK() {
    CheckDir $PK_DIR

    export PATH=$RISCV/bin:$PATH #for cross compile

    local build_dir=$PK_DIR/build

    if [ "$build_mode" == 'clean' ] || [ ! -d $build_dir ]; then
        rm -rf $build_dir
        CreatePKBuildDir $build_dir
    fi

    cd $build_dir
    make -j $build_cores
    make install

    CheckFile $build_dir/pk
}

function CreateLLVMBuildDir {
    local build_dir=$1
    mkdir $build_dir
    cd $build_dir
    cmake -DLLVM_TARGETS_TO_BUILD="X86;RISCV" \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_PARALLEL_LINK_JOBS=1 \
        -DCMAKE_BUILD_TYPE=Debug \
        -Wl,-no-keep-memory \
        -Wl,--reduce-memory-overheads \
        -DBUILD_SHARED_LIBS=ON \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_USE_LINKER=gold \
        -G Ninja ../llvm/
    cd - >/dev/null
}

function BuildLLVM {
    CheckDir $LLVM_DIR

    local build_dir=$LLVM_DIR/build

    if [ "$build_mode" == 'clean' ] || [ ! -d $build_dir ]; then
        rm -rf $build_dir
        CreateLLVMBuildDir $build_dir
    fi

    cd $build_dir
    ninja -j $build_cores

    CheckFile $build_dir/bin/llvm-config
}



function BuildRISCVOpcodes()
{
    CheckDir $RISCV_OPCODE_DIR
    cd $RISCV_OPCODE_DIR
    make
    CheckFile $RISCV_OPCODE_DIR/instr_dict.yaml
}

function BuildGem5() {
    CheckDir $GEM5_DIR

    local build_dir=$GEM5_DIR/build
    if [ "$build_mode" == 'clean' ] || [ ! -d $build_dir ];then
        echo "Clean build GEM5"
        rm -rf $build_dir
    fi

    cd $GEM5_DIR
    scons build/RISCV/gem5.opt -j $build_cores
    cd - > /dev/null
    CheckFile $build_dir/RISCV/gem5.opt
}


function CreateTVMDLRBuildDir() {
    local build_dir=$1

    mkdir -p $build_dir
    cd $build_dir

    cmake .. -DCMAKE_INSTALL_PREFIX=$TVMDLR_DIR/install -DCMAKE_BUILD_TYPE=Debug

    cd - > /dev/null
}


function BuildTVMDlr()
{
    target=${1:-riscv}
    CheckDir $TVMDLR_DIR

    if [ "$target" == "riscv" ] && [ ! -f "$RISCV/bin/riscv64-unknown-elf-gcc" ]; then
        echo "$RISCV/bin/riscv64-unknown-elf-gcc"
        LogError "riscv-unknow-elf-gcc doest not exist!"
        exit
    fi

    if [ "$target" == "riscv" ] && [ ! -f "$RISCV/bin/riscv64-unknown-elf-g++" ]; then
        LogError "riscv-unknwn-elfg++ doest not exist!"
        exit
    fi

    if [ "$target" == "riscv" ];then
        export CC=$RISCV/bin/riscv64-unknown-elf-gcc
        export CXX=$RISCV/bin/riscv64-unknown-elf-g++
    else
        export CC=$(which gcc)
        export CXX=$(which g++)

    fi

    local build_dir=$TVMDLR_DIR/build

    if [ "$build_mode" == 'clean' ] || [ ! -d $build_dir ];then
        echo "Clean build TVM DLR"
        rm -rf $build_dir
        CreateTVMDLRBuildDir $build_dir
    fi

    cd $build_dir
    make -j $build_cores
    make install

    if [ "$target" == "riscv" ];then
        export CC=$(which gcc)
        export CXX=$(which g++)
    fi

    cd - > /dev/null
}


function CreateTVMBuildDir()
{
    local build_dir=$1
    local config_template=$TVM_DIR/cmake/config.cmake
    local build_config=$build_dir/config.cmake

    mkdir -p $build_dir; cd $build_dir

    CheckDir $LLVM_DIR
    llvm_config=$LLVM_DIR/build/bin/llvm-config

    if [ ! -f $llvm_config ];then
        LogError "There is no llvm-config in LLVM/build"
        exit 1
    fi

    cp $config_template $build_config

    string_to_replace="set(USE_LLVM OFF)"
    replacement_string="set(USE_LLVM \"$llvm_config --ignore-libllvm \")"
    sed -i "s|$string_to_replace|$replacement_string|g" "$build_config"

    string_to_replace="set(USE_CUDA OFF)"
    replacement_string="set(USE_CUDA ON)"
    sed -i "s|$string_to_replace|$replacement_string|g" "$build_config"

    echo "set(HIDE_PRIVATE_SYMBOLS ON)" >>  $build_config

    cmake .. -DCMAKE_BUILD_TYPE="RelWithDebInfo"
    cd - >/dev/null
}

function BuildTVM()
{
    CheckDir $TVM_DIR

    local build_dir=$TVM_DIR/build

    if [ "$build_mode" == 'clean' ] || [ ! -d $build_dir ];then
        LogNotice "Clean build TVM"
        rm -rf $build_dir
        CreateTVMBuildDir $build_dir
    fi

    cd $build_dir
    make -j$build_cores
}

function CreateHalideBuildDir() {
    local build_dir=$1

    CheckDir $LLVM_DIR
    local llvm_build_lib_dir=$LLVM_DIR/build/lib/cmake/llvm
    CheckDir $llvm_build_lib_dir

    cd $HALIDE_DIR
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=install \
        -DCMAKE_BUILD_TYPE=Debug \
        -DLLVM_DIR=$llvm_build_lib_dir \
        -S . -B $build_dir
    cd - > /dev/null
}

function BuildHalide()
{
    CheckDir $HALIDE_DIR

    local build_dir=$HALIDE_DIR/build

    if [ "$build_mode" == 'clean' ] || [ ! -d $build_dir ];then
        LogNotice "Clean build Halide"
        rm -rf $build_dir
        CreateHalideBuildDir $build_dir
    fi

    cd $build_dir
    ninja install

    CheckFile $build_dir/src/libHalide.so
}

############
### MAIN ###
############

if [ -d ~/workspace/venv ]; then
    source ~/workspace/venv/bin/activate
fi
