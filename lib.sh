#!/bin/bash

UTIL_DIR=$(dirname $(realpath $BASH_SOURCE))
PROJECT_DIR=$UTIL_DIR/..


COLOR_CYAN="\e[36m"
COLOR_RED="\e[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_DEF="\e[39m"

ERR_UNKNOWN=1
ERR_SIM_FAIL=2


###################
##    logging    ##
###################

function ColorEcho()
{
	local msg="$1"
	local color="$2"

	echo -e "${color}$msg${COLOR_DEF}"
}

function LogError()
{
	local msg="$1"
	ColorEcho "$msg" $COLOR_RED
}

function LogNotice()
{
	local msg="$1"
	ColorEcho "$msg" $COLOR_YELLOW
}

function LogInfo()
{
	local msg="$1"
	ColorEcho "$msg" $COLOR_CYAN
}

######################
##    log report    ##
######################

function CreateLogReportFile()
{
	local path=$1
	export LOG_FILE=$1
	> $LOG_FILE
}

function UpdateLogReport()
{
    local fmt="$1"
    local msg="$2"
    printf "$fmt" "$msg" >> $LOG_FILE

    #local ret=$?

	#if [ $ret -eq 0 ]; then
	#	printf "%-50s  SUCCESS\n" "[$case_name]" >> $LOG_FILE
	#else
	#	printf "%-50s  FAILED  [%s]\n" "[$case_name]" "$(ErrCode2Str $ret)" >> $LOG_FILE
	#fi

	#printf "\n"
}

function SummarizeLogReport()
{
	if [ -z "$LOG_FILE" ]; then
		LogError "\$LOG_FILE not set"
		return -1
	fi

	local tmp=$(mktemp)

	sort $LOG_FILE > $tmp
	mv $tmp $LOG_FILE

	local success_cnt=$(grep "SUCCESS" $LOG_FILE | wc -l)
	local fail_cnt=$(grep "FAILED" $LOG_FILE | wc -l)

	echo "================================================" >> $LOG_FILE
	echo -e "=> [$success_cnt] cases generated, [$fail_cnt] cases failed" >> $LOG_FILE

	if [ $fail_cnt -eq 0 ]; then
		return 0
	else
		return -1
	fi
}

function ShowLogReport()
{
	cat $LOG_FILE
}

##########################
##    util functions    ##
##########################

function ErrCode2Str() {
	local code=$1

	case $code in
		$ERR_SIM_FAIL) echo "simulation error" ;;
		*) echo "unknown" ;;
	esac
}

function CreateLinks() {
	local srcs=$1
	local base_dir=${2:-""}

	for src in $srcs; do
		[ -n "$base_dir" ] && src=$base_dir/$src
		if [ -f $src ] || [ -d $src ]; then
			ln -sf $(realpath $src) .
		fi
	done
}

function CopyOrMoveFiles() {
    local cmd=$1
	local srcs=$2
	local src_base_dir=${3:-""}
	local dst_dir=${4:-"."}

	for src in $srcs; do
		[ -n "$src_base_dir" ] && src=$src_base_dir/$src
		if [ -f $src ] || [ -L $src ] || [ -d $src ]; then
            if [ $cmd == "copy" ]; then
			    cp -Hrf $(realpath $src) $dst_dir
            else
                mv -f $(realpath $src) $dst_dir
            fi
		fi
	done
}

function CopyFiles() {
    local srcs=$1
	local src_base_dir=${2:-""}
	local dst_dir=${3:-"."}

    CopyOrMoveFiles "copy" "$srcs" "$src_base_dir" "$dst_dir"
}

function MoveFiles() {
    local srcs=$1
	local src_base_dir=${2:-""}
	local dst_dir=${3:-"."}

    CopyOrMoveFiles "move" "$srcs" "$src_base_dir" "$dst_dir"
}

function CheckSts() {
	local sts=$1
	local tag=${2:-"execution"}

	if [ $sts -ne 0 ]; then
		LogError "=> $tag failed"
		exit $sts
	fi
}

function CheckFileExist() {
	local files=$1
	local err=${2:-$ERR_UNKNOWN}

	for file in $files; do
		if [ ! -f "$file" ]; then
			echo "[ERROR] Cannot find file [$file]!"
			exit $err
		fi
	done
}

function CheckDirExist() {
	local dir=$1

	if [ ! -d "$dir" ]; then
		echo "[ERROR] Cannot find dir [$dir]!"
		exit 1
	fi
}


