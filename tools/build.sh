#!/bin/bash

## ProjectX Build Script ##

# Display Script Usage
usage()
 {
   echo ""
   echo "${txtbld}Usage:${txtrst}"
   echo "  ./build.sh [options] [device]"
   echo ""
   echo "${txtbld}  Options:${txtrst}"
   echo "    -c# Cleaning options before build:"
   echo "        1 - make clobber"
   echo "        2 - make dirty"
   echo "        3 - make magic"
   echo "        4 - make kernelclean"
   echo "        5 - remove /target and Ccache"
   echo "    -j# Set jobs"
   echo "    -s  Sync before build"
   echo "    -l  Save build output in make.log"
   echo ""
   echo "${txtbld}  Example:${txtrst}"
   echo "    bash build.sh -c1 -j18 hammerhead"
   echo ""
   exit 1
 }

# Prepare output colouring commands
red=$(tput setaf 1) # red
grn=$(tput setaf 2) # green
blu=$(tput setaf 4) # blue
cya=$(tput setaf 6) # cyan
txtbld=$(tput bold) # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgrn=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
bldcya=${txtbld}$(tput setaf 6) # cyan
txtrst=$(tput sgr0) # Reset

  if [[ ! -d ".repo" ]]; then
    echo ""
    read -p "${bldred}No .repo directory found in ${PWD}. Do you want to download the source here? [y/n]: ${txtrst}" dwnld

      until [[ "$dwnld" -eq y ]] || [[ "$dwnld" -eq n ]]; do
	echo ""
	read -p "${bldred}Enter [y/n]: ${txtrst}" dwnld
      done
    echo ""

      if [[ "$dwnld" -eq y ]]; then
	echo "${bldgrn}Initializing source...${txtrst}"
	repo init -u git://github.com/ProjectX-Android/manifest.git -b lollipop-5.1
	FCheck=$?
	echo ""

	  if [[ "$FCheck" -ne 0 ]]; then
	    echo "${bldred}Failed to initialize repo, error code: ${FCheck}${txtrst}"
	    exit 2
	  else
	    echo "${bldcya}Repo initialized!${txtrst}"
	  fi
	echo ""
	echo "${bldgrn}Downloading source...${txtrst}"
	repo sync -j200
	FCheck=$?
	echo ""

	  if [[ "$FCheck" -ne 0 ]]; then
	    echo "${bldred}Failed to download repo, error code: ${FCheck}${txtrst}"
	    exit 3
	  else
	    echo "${bldcya}Repo downloaded!${txtrst}"
	  fi

	echo "${bldgrn}Adding execute permissons...${txtrst}"
	chmod a+x -R ./*
	FCheck=$?
	echo ""

	  if [[ "$FCheck" -ne 0 ]]; then
	    echo "${bldred}Failed to add execute permissons, error code: ${FCheck}${txtrst}"
	    exit 4
	  else
	    echo "${bldcya}Execute permissions added!${txtrst}"
	  fi
      else
	echo "${bldred}Will not download the source!${txtrst}"
	exit 5
      fi
  fi

  if [[ ! -d "vendor/px" ]]; then
    echo "${red}No vendor/px directory found.  Is this a ProjectX build tree?${txtrst}"
    exit 6
  fi
device="$1"

  if [[ ! -d "vendor/*/$device" ]]; then
    echo "${bldred}No proprietary files found!${txtrst}"
    exit 7
  fi

# figure out the output directories
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
thisDIR="${PWD##*/}"

  if [[ -z "${OUT_DIR_COMMON_BASE}" ]]; then
    export OUTDIR="$DIR/out"
    echo ""
    echo "${cya}No external out, using default ($OUTDIR)${txtrst}"
    echo ""
  else
    export OUTDIR="$OUT_DIR_COMMON_BASE"
    echo ""
    echo "${cya}External out DIR is set ($OUTDIR)${txtrst}"
    echo ""
  fi

# get OS (linux / Mac OS x)
IS_DARWIN=$(uname -a | grep Darwin)

if [[ -n "$IS_DARWIN" ]]; then
    CPUS=$(sysctl hw.ncpu | awk '{print $2}')
    DATE=gdate
else
    CPUS=$(grep "^processor" /proc/cpuinfo | wc -l)
    DATE=date
fi

export OPT_CPUS=$(bc <<< "($CPUS-1)*2")
export USE_CCACHE=1
opt_clean=0
opt_dex=0
opt_initlogo=0
opt_jobs="$OPT_CPUS"
opt_sync=0
opt_pipe=0
opt_verbose=0
opt_log=0


  while getopts "c:j:s:u:l" opt; do
    case "$opt" in
      c) opt_clean="$OPTARG" ;;
      j) opt_jobs="$OPTARG" ;;
      s) opt_sync=1 ;;
      l) opt_log=1 ;;
      *) usage
    esac
  done
shift $((OPTIND-1))

  if [[ "$#" -ne 1 ]]; then
    usage
  fi

echo "${cya}Starting ${ppl}ProjectX...${txtrst}"

  if [[ "$opt_clean" -eq 1 ]]; then
    make clean >/dev/null
    echo ""
    echo "${bldblu}Out is clean${txtrst}"
    echo ""

  elif [[ "$opt_clean" -eq 2 ]]; then
    make dirty >/dev/null
    echo ""
    echo "${bldblu}Out is dirty${txtrst}"
    echo ""

  elif [[ "$opt_clean" -eq 3 ]]; then
    make magic >/dev/null
    echo ""
    echo "${bldblu}Enjoy your magical adventure${txtrst}"
    echo ""

  elif [[ "$opt_clean" -eq 4 ]]; then
    make kernelclean >/dev/null
    echo ""
    echo "${bldblu}All kernel components have been removed${txtrst}"
    echo ""

  elif [[ "$opt_clean" -eq 5 ]]; then
    export USE_CCACHE=1
    rm -rf "${CCACHE_DIR}"
    rm -rf target
    echo ""
    echo "${bldblu}Target folder and Ccache is clean${txtrst}"
    echo ""
 fi

# sync with latest sources
  if [[ "$opt_sync" -ne 0 ]]; then
    echo ""
    echo "${bldblu}Fetching latest sources${txtrst}"
    repo sync -j"$opt_jobs"
    echo ""
  fi

rm -f "$OUTDIR/target/product/$device/obj/KERNEL_OBJ/.version"

# get time of startup
t1=$($DATE +%s)

# setup environment
echo "${bldblu}Setting up environment${txtrst}"
. build/envsetup.sh

# Remove system folder (this will create a new build.prop with updated build time and date)
rm -f "$OUTDIR/target/product/$device/system/build.prop"
rm -f "$OUTDIR/target/product/$device/system/app/*.odex"
rm -f "$OUTDIR/target/product/$device/system/framework/*.odex"

# start compilation

# lunch device
  if [[ "$opt_log" -ne 0 ]]; then
    echo ""
    echo "${bldblu}Compiling ROM with log${txtrst}"
    lunch "ch_$device-userdebug" && make bacon "-j$opt_jobs" > make_$device.log 2>&1;
  else
    echo ""
    echo "${bldblu}Compiling ROM${txtrst}"
    lunch "ch_$device-userdebug" && make bacon "-j$opt_jobs";
  fi

# finished? get elapsed time
FCheck=$?

  if [[ ${FCheck} -ne 0 ]]; then
    echo "${bldred}Build failed, error code: ${FCheck}${txtrst}"
    exit 8
  fi
t2=$($DATE +%s)

tmin=$(( (t2-t1)/60 ))
tsec=$(( (t2-t1)%60 ))

echo "${bldgrn}Total time elapsed:${txtrst} ${grn}$tmin minutes $tsec seconds${txtrst}"
v
