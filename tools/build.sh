#!/bin/bash -x

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
   echo "    -j# Set jobs"
   echo "    -l#  Save output in log(s)"
   echo "	 1 - toolchains"
   echo "	 2 - make"
   echo "	 3 - both"
   echo "    -n  Incase you never lunched the device before"
   echo "    -s  Sync before build"
   echo "    -t  Build SaberMod Toolchains before build"
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

  if [[ ! -d .repo ]]; then
    echo -e "${bldred}No .repo directory found.  Is this an Android build tree?${txtrst}"
    exit 1
  fi

  if [[ ! -d vendor/px ]]; then
    echo "${bldred}No vendor/px directory found.  Is this a ProjectX build tree?${txtrst}"
    exit 6
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
#device="$1"
opt_clean=0
opt_jobs="$OPT_CPUS"
opt_sync=0
opt_log=0
opt_tc=0
opt_upl=0
opt_init=0
opt_fls=0

  while getopts "c:hj:l:nstu" opt; do
    case "$opt" in
      c) opt_clean="$OPTARG" ;;
      h) usage ;;
      j) opt_jobs="$OPTARG" ;;
      l) opt_log="$OPTARG" ;;
      n) opt_fls=1 ;;
      s) opt_sync=1 ;;
      t) opt_tc=1 ;;
      u) opt_upl=1 ;;
      *) echo "${bldred}incorrect parameter${txtrst}"
	 usage ;;
    esac
  done
shift $((OPTIND-1))

  if [[ $# -ne 1 ]]; then
    usage
  fi
device="$1"

  if [[ -z $device ]]; then
    echo "${bldred}No device specified${txtrst}"
    usage
  fi

# Check if proprietary files are downloaded
  if [[ $opt_fls -eq 0 ]] && [[ ! -d vendor/*/$device ]]; then
    echo "${bldred}No proprietary files found!${txtrst}"
    exit 7
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
  fi

# Sync with latest sources
  if [[ $opt_sync -ne 0 ]]; then
    echo ""
    echo "${bldblu}Fetching latest sources${txtrst}"
    repo sync -j"$opt_jobs"
    echo ""
  fi
rm -f "$OUTDIR/target/product/$device/obj/KERNEL_OBJ/.version"

  if [[ ! -d prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9-sm ]]; then
    opt_tc=1
    echo "${bldblu}Toolchain arm-linux-androideabi-4.9 not found, creating it...${txtrst}"
  fi

  if [[ ! -d prebuilts/gcc/linux-x86/arm/arm-eabi-4.9-sm ]]; then
    opt_tc=1
    echo "${bldblu}Toolchain arm-eabi-4.9 not found, creating it...${txtrst}"
  fi

  if [[ $opt_tc -eq 1 ]]; then
    src_dir=$(pwd)
      if [[ ! -d $HOME/sm-tc ]]; then
        echo "${bldblu}Directory '$HOME/sm-tc' not found, creating it...${txtrst}"
        mkdir -p $HOME/sm-tc
        opt_init=1

      elif [[ ! -d $HOME/sm-tc/.repo ]]; then
        echo "${bldblu}No repo initialized in '$HOME/sm-tc' Initializing now...${txtrst}"
        opt_init=1
      fi
    cd $HOME/sm-tc
      if [[ $opt_init -eq 1 ]]; then
        repo init -u https://gitlab.com/SaberMod/sabermod-manifest.git -b master
	FCheck=$?

	  if [[ $FCheck -ne 0 ]]; then
	    echo "${bldred}Failed to initialize repo in '$HOME/sm-tc', error code: $FCheck${txtrst}"
	    exit 8
	  fi
      fi
    echo "${bldgrn}Syncing with the SaberMod repo...${txtrst}"
    repo sync
    FCheck=$?

      if [[ $FCheck -ne 0 ]]; then
	echo "${bldred}Syncing with the SaberMod repo failed, error code $FCheck${txtrst}"
	exit 9
      fi
    cd smbuild
    echo ""
    read -p "${bldgrn}How much toolchains do you want to make? (ex. 2): ${txtrst}" mch_tc
    shft_tc=0

      until [[ $shft_tc -eq $mch_tc ]]; do
	shft_tc=$(( shft_tc + 1 ))
	echo ""
	read -p "${bldgrn}Enter toolchain ${shft_tc}'s name (ex. arm-eabi-4.9): ${txtrst}" bld_tc
	echo "$bld_tc" | grep "arm-" &>/dev/null
	FCheck=$?

	  if [[ $FCheck -eq 0 ]]; then
	    fldr=arm
	    cd $fldr
	  fi
	echo "$bld_tc" | grep "aach64-" &>/dev/null
	FCheck=$?

	  if [[ $FCheck -eq 0 ]]; then
	    fldr=aarch64
	    cd $fldr
	  fi
	echo ""

	  if [[ $opt_log -eq 1 ]] || [[ $opt_log -eq 3 ]]; then
            echo "${bldblu}Compiling toolchain $bld_tc with log${txtrst}"
	    bash $bld_tc > $HOME/tc_$bld_tc.log &>/dev/null
	  else
	    bash $bld_tc
	    FCheck=$?

	     if [[ $FCheck -ne 0 ]]; then
	      echo "${bldred}Failed to build $bld_tc toolchain${txtrst}"
	      exit 10
	     fi
	  fi
	echo ""

	  if [[ $bld_tc -eq arm-eabi-4.9 ]]; then
	    mv "$HOME/tmp/arm-gnueabi-4.9" "$src_dir/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9-sm"
	  else
	    echo "${txtblu}Moving $HOME/tmp/$bld_tc to $src_dir/prebuilts/gcc/linux-x86/$fldr/${bld_tc}-sm...${txtrst}"
	    mv "$HOME/tmp/$bld_tc" "$src_dir/prebuilts/gcc/linux-x86/$fldr/${bld_tc}-sm"
	    FCheck=$?
	  fi
	echo ""

	  if [[ $FCheck -eq 0 ]]; then
	    echo "${bldcya}Toolchain $bld_tc copied.${txtrst}"
	  else
	    echo "${bldred}Failed to copy toolchain ${bld_tc}.${txtrst}"
	    exit 11
	  fi
      done
      if [[ $mch_tc -gt 1 ]]; then
	xtr="'s"
      else
	xtr=""
      fi
    cd "$src_dir"
  fi
# Get time of startup
t1=$($DATE +%s)

# Setup environment
echo "${bldblu}Setting up environment${txtrst}"
. build/envsetup.sh &>/dev/null

  if [[ $? -eq 126 ]]; then
    echo "${bldblu}Changing build/envsetup permissions...${txtrst}"
    chmod a+x build/envsetup.sh
    build/envsetup.sh
  fi

# Remove system folder (this will create a new build.prop with updated build time and date)
rm -f "$OUTDIR/target/product/$device/system/build.prop"
rm -f "$OUTDIR/target/product/$device/system/app/*.odex"
rm -f "$OUTDIR/target/product/$device/system/framework/*.odex"

# Start compilation

# Lunch & build device
echo ""

  if [[ $opt_log -eq 2 ]] || [[ $opt_log -eq 3 ]]; then
    echo "${bldblu}Compiling ROM with log${txtrst}"
    lunch "px_$device-userdebug" && make $device "-j$opt_jobs" > $HOME/make_$device.log &>/dev/null
  else
    echo "${bldblu}Compiling ROM${txtrst}"
    lunch "px_$device-userdebug" && make $device "-j$opt_jobs";
  fi
FCheck=$?

# Check build completion
  if [[ $FCheck -ne 0 ]]; then
    echo "${bldred}Build failed, error code: ${FCheck}${txtrst}"
    exit 12
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
        exit 13
      fi
  fi
# Finished? Get elapsed time
t2=$($DATE +%s)

tmin=$(( (t2-t1)/60 ))
tsec=$(( (t2-t1)%60 ))

echo "${bldgrn}Total time elapsed:${txtrst} ${grn}$tmin minutes $tsec seconds${txtrst}"
exit 0
