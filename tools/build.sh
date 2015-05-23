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
   echo "    -h  Display this help page"
   echo "    -j# Set jobs"
   echo "    -l  Save build output in make.log"
   echo "    -s  Sync before build"
   echo "    -u  Upload build via FTP after completion"
   echo ""
   echo "${txtbld}  Example:${txtrst}"
   echo "    bash build.sh -c1 -j18 hammerhead"
   echo ""
   exit 1
 }

# Prepare output colouring commands
red=$(tput setaf 1) # Red
grn=$(tput setaf 2) # Green
blu=$(tput setaf 4) # Blue
cya=$(tput setaf 6) # Cyan
txtbld=$(tput bold) # Bold
bldred=${txtbld}${red} # Bold Red
bldgrn=${txtbld}${grn} # Green
bldblu=${txtbld}${blu} # Blue
bldcya=${txtbld}${cya} # Cyan
txtrst=$(tput sgr0) # Reset

  if [[ ! -d vendor/px ]]; then
    echo "${red}No vendor/px directory found.  Is this a ProjectX build tree?${txtrst}"
    exit 6
  fi

# Check if proprietary files are downloaded
  if [[ ! -d vendor/*/$device ]]; then
    echo "${bldred}No proprietary files found!${txtrst}"
    exit 7
  fi

# Find the output directories
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
thisDIR="${PWD##*/}"

  if [[ -z $OUT_DIR_COMMON_BASE ]]; then
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

# Get OS (Linux / Mac OS X)
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
device="$1"
opt_clean=0
opt_dex=0
opt_initlogo=0
opt_jobs="$OPT_CPUS"
opt_sync=0
opt_pipe=0
opt_verbose=0
opt_log=0
opt_upl=0

  while getopts "c:h:j:l:s:u" opt; do
    case "$opt" in
      c) opt_clean="$OPTARG" ;;
      h) usage ;;
      j) opt_jobs="$OPTARG" ;;
      l) opt_log=1 ;;
      s) opt_sync=1 ;;
      u) opt_upl=1 ;;
      *) usage
    esac
  done
shift $((OPTIND-1))

  if [[ $# -ne 1 ]]; then
    usage
  fi

echo "${cya}Starting ${ppl}ProjectX...${txtrst}"

  if [[ $opt_clean -eq 1 ]]; then
    make clean >/dev/null
    echo ""
    echo "${bldblu}Out is clean${txtrst}"
    echo ""

  elif [[ $opt_clean -eq 2 ]]; then
    make dirty >/dev/null
    echo ""
    echo "${bldblu}Out is dirty${txtrst}"
    echo ""

  elif [[ $opt_clean -eq 3 ]]; then
    make magic >/dev/null
    echo ""
    echo "${bldblu}Enjoy your magical adventure${txtrst}"
    echo ""

  elif [[ $opt_clean -eq 4 ]]; then
    make kernelclean >/dev/null
    echo ""
    echo "${bldblu}All kernel components have been removed${txtrst}"
    echo ""

  elif [[ $opt_clean -eq 5 ]]; then
    export USE_CCACHE=1
    rm -rf "${CCACHE_DIR}"
    rm -rf target
    echo ""
    echo "${bldblu}Target folder and Ccache is clean${txtrst}"
    echo ""
 fi

# Sync with latest sources
  if [[ $opt_sync -ne 0 ]]; then
    echo ""
    echo "${bldblu}Fetching latest sources${txtrst}"
    repo sync -j"$opt_jobs"
    echo ""
  fi

rm -f "$OUTDIR/target/product/$device/obj/KERNEL_OBJ/.version"

# Get time of startup
t1=$($DATE +%s)

# Setup environment
echo "${bldblu}Setting up environment${txtrst}"
./build/envsetup.sh

# Remove system folder (this will create a new build.prop with updated build time and date)
rm -f "$OUTDIR/target/product/$device/system/build.prop"
rm -f "$OUTDIR/target/product/$device/system/app/*.odex"
rm -f "$OUTDIR/target/product/$device/system/framework/*.odex"

# Start compilation

# Lunch & build device
  if [[ $opt_log -ne 0 ]]; then
    echo ""
    echo "${bldblu}Compiling ROM with log${txtrst}"
    lunch "px_$device-userdebug" && make $device "-j$opt_jobs" > make_$device.log 2>&1;
  else
    echo ""
    echo "${bldblu}Compiling ROM${txtrst}"
    lunch "px_$device-userdebug" && make $device "-j$opt_jobs";
  fi
FCheck=$?

# Check build completion
  if [[ $FCheck -ne 0 ]]; then
    echo "${bldred}Build failed, error code: ${FCheck}${txtrst}"
    exit 8
  fi

# FTP file check
ftp_fls ()
 {
  echo ""
    if [[ -z $file ]]; then
      echo "${bldred}Error: file '$HOME/$file' is missing or empty${txtrst}"
      echo ""
      read -p "${bldblu}Enter the FTP server $ftp_usg here: ${txtrst}" ftp_tmp
      echo "$ftp_tmp" > $HOME/$file
    fi
      echo ""
      echo "${bldgrn}Using '$ftp_cntnt' as FTP server $file_usg${txtrst}"
 }

# Upload via FTP (-u)
  if [[ $opt_upl -eq 1 ]]; then
    # FTP server address
    file=.ftp_host
    ftp_host=$(cat $HOME/$file &>/dev/null)
    ftp_cntnt="$ftp_host"
    ftp_usg=address
    ftp_fls

    # FTP server username
    file=.ftp_usr
    ftp_usr=$(cat $HOME/$file &>/dev/null)
    ftp_cntnt="$ftp_usr"
    ftp_usg=username
    ftp_fls

    # FTP server password
    file=.ftp_passwd
    ftp_passwd=$(cat $HOME/$file &>/dev/null)
    ftp_cntnt="$ftp_passwd"
    ftp_usg=password
    ftp_fls

    # Start upload
    echo ""
    echo "${bldblu}Uploading '$OUTDIR/target/product/$device/$PX_VERSION' to '$FTP_HOST'...${txtrst}"
    curl -T "$OUTDIR/target/product/$device/$PX_VERSION" -u "$FTP_USR":"$FTP_PASSWD" "ftp://$FTP_HOST"
    FCheck=$?
    echo ""

      if [[ $FCheck -eq 0 ]]; then
        echo "${bldcya}'$PX_VERSION' uploaded to '$FTP_HOST'${txtrst}"
      else
        echo "${bldred}'$PX_VERSION' failed to upload to '$FTP_HOST', error code '$FCheck'${txtrst}"
        exit 9
      fi
  fi
# Finished? Get elapsed time
t2=$($DATE +%s)

tmin=$(( (t2-t1)/60 ))
tsec=$(( (t2-t1)%60 ))

echo "${bldgrn}Total time elapsed:${txtrst} ${grn}$tmin minutes $tsec seconds${txtrst}"
exit 0
