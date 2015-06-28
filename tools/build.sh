#!/bin/bash

## ProjectX Build Script ##

# Display Script Usage
usage()
 {
   echo ""
   echo "${txtbld}Usage:${txtrst}"
   echo "  bash build.sh [options] [device] [variant]"
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
   echo "    -s  Sync before build"
   echo "    -t#  Set amount of SaberMod Toolchains to build (if not specified, none are built)"
   echo "    -u  Upload build via FTP after completion"
   echo ""
   echo "${txtbld}  Variants:${txtrst}"
   echo "    -userdebug"
   echo "    -user (default)"
   echo ""
   echo "${txtbld}  Example:${txtrst}"
   echo "    bash build.sh -c1 -j18 hammerhead userdebug"
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
    echo "${bldred}No .repo directory found.  Is this an Android build tree?${txtrst}"
    exit 2
  fi

  if [[ ! -d vendor/px ]]; then
    echo "${bldred}No vendor/px directory found.  Is this a ProjectX build tree?${txtrst}"
    exit 3
  fi

# Find the output directories
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
thisSRCDIR="${PWD##*/}"

  if [[ -z $OUT_DIR_COMMON_BASE ]]; then
    export OUTDIR="$DIR/out"
    echo ""
    echo "${cya}No external out, using default ($OUTDIR)${txtrst}"
    echo ""
  else
    export OUTDIR="$OUT_DIR_COMMON_BASE"
    echo ""
    echo "${cya}External out DIR is set ($OUTDIR)${txtrst}"
    echo "${cya}But $OUTDIR/$thisSRCDIR will be used${txtrst}"
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
opt_clean=0
opt_jobs="$OPT_CPUS"
opt_sync=0
opt_log=0
opt_tc=0
opt_upl=0
opt_init=0
mch_tc=0
mch_tc_bckp=0
no_tc1=0
no_tc2=0

  while getopts "c:hj:l:s:t:u" opt; do
    case "$opt" in
      c) opt_clean="$OPTARG" ;;
      h) usage ;;
      j) opt_jobs="$OPTARG" ;;
      l) opt_log="$OPTARG" ;;
      s) opt_sync=1 ;;
      t) opt_tc=1 && mch_tc="$OPTARG" && mch_tc_bckp=$mch_tc ;;
      u) opt_upl=1 ;;
      *) echo "${bldred}incorrect parameter${txtrst}"
	 usage ;;
    esac
  done
shift $((OPTIND-1))

device="$1"
variant=$2

  if [[ -z $device ]]; then
    echo "${bldred}No device specified${txtrst}"
    usage
  fi

  if [[ -z $variant ]]; then
    variant=user
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

yn_check()
{
 until [[ $yorn = y || $yorn = n ]]; do
   echo ""
   read -p "${bldred}Please enter [y/n]: ${txtrst}" yorn
 done
}

  if [[ ! -d prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 ]]; then
    echo "${bldblu}Toolchain arm-linux-androideabi-4.9 not found.${txtrst}"
    echo ""
    echo "${bldblu}Do you have it backed up somewhere?${txtrst}"
    read -p "${bldblu}Enter it's path here, leave empty if you haven't: ${txtrst}" tc_dir

      if [[ -z $tc_dir ]]; then
        read -p "Do you want to build it? [y/n]: " yorn
        yn_check
	echo ""

          if [[ $yorn = n ]]; then
	    echo "${bldred}arm-linux-androideabi-4.9 toolchain won't be built!${txtrst}"
          else
	    echo "${bldblu}arm-linux-androideabi-4.9 toolchain will be built!${txtrst}"
	    no_tc1=1
	    opt_tc=1
	    mch_tc=1
          fi
      else

          until [[ -d $tc_dir ]]; do
	    echo ""
	    echo "${bldred}Directory not found, try again: ${txtrst}"
	  done
	echo ""
	echo "${bldblu}Copying $tc_dir to prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9${txtrst}"
	cp -R "$tc_dir" prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9
      fi
  fi

  if [[ ! -d prebuilts/gcc/linux-x86/arm/arm-eabi-4.9 ]]; then
    echo "${bldblu}Toolchain arm-eabi-4.9 not found.${txtrst}"
    echo ""
    echo "${bldblu}Do you have it backed up somewhere?${txtrst}"
    read -p "${bldblu}Enter it's path here, leave empty if you haven't: ${txtrst}" tc_dir

      if [[ -z $tc_dir ]]; then
        read -p "Do you want to build it? [y+n]: " yorn
        yn_check

          if [[ $yorn = n ]]; then
            echo "${bldred}arm-eabi-4.9 toolchain won't be built!${txtrst}"
          else
            echo "${bldblu}arm-eabi-4.9 toolchain will be built!${txtrst}"

              if [[ $mch_tc && $no_tc1=1 ]]; then
                mch_tc=2
              else
	        opt_tc=1
	        mch_tc=1
	      fi
            no_tc2=1
	    opt_tc=1
          fi
      else

          until [[ -d $tc_dir ]]; do
            echo ""
            echo "${bldred}Directory not found, try again: ${txtrst}"
          done
        echo ""
        echo "${bldblu}Copying $tc_dir to prebuilts/gcc/linux-x86/arm/arm-eabi-4.9${txtrst}"
        cp -R "$tc_dir" prebuilts/gcc/linux-x86/arm/arm-eabi-4.9
      fi
  fi

  if [[ $opt_tc -eq 1 ]]; then

    echo "${bldblu}What toolchain repository do you want to use?${txtrst}"
    read -p "${bldblu}Leave empty for default ($HOME/sm-tc): ${txtrst}" SM_dir

      if [[ -z $SM_dir ]]; then
	SM_dir=$HOME/sm-tc
      fi

      if [[ $SM_dir != $HOME/sm-tc ]]; then

	  until [[ -d $SM_dir ]]; do
	    echo ""
	    echo "${bldred}The directory '$SM_dir' doesn't exist, try again${txtrst}"
	    read -p "${bldred}Leave empty for default ($HOME/sm-tc): ${txtrst}" SM_dir
	  done
      elif [[ ! -d $SM_dir ]]; then
        echo "${bldblu}Directory '$HOME/sm-tc' not found, creating it...${txtrst}"
        mkdir -p "$HOME/sm-tc"
        opt_init=1
      fi

      if [[ ! -d $SM_dir/.repo && opt_init -ne 1 ]]; then
        echo "${bldblu}No repo initialized in '$HOME/sm-tc' Initializing now...${txtrst}"
        opt_init=1
      elif [[ ! -d $SM_dir/smbuild ]]; then
	echo "${bldred}Is this a SaberMod build tree?${txtrst}"
	exit 7
      fi
    cd "$SM_dir"
      if [[ $opt_init -eq 1 ]]; then
        repo init -u https://gitlab.com/SaberMod/sabermod-manifest.git -b master
	FCheck=$?

          if [[ $FCheck -ne 0 ]]; then
            echo "${bldred}Failed to initialize repo in '$SM_dir', error code: $FCheck${txtrst}"
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
    shft_tc=0

      until [[ $shft_tc -eq $mch_tc ]]; do
	  if [[ $no_tc1 -eq 1 ]]; then
	    echo "${bldblu}Building arm-linux-androideabi-4.9 Toolchain because it is missing in the source code...${txtrst}"
	    thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
            cd arm
	    bash arm-linux-androideabi-4.9
            FCheck=$?

              if [[ $FCheck -ne 0 ]]; then
               echo "${bldred}Failed to build arm-linux-androideabi-4.9 toolchain${txtrst}"
                exit 10
              fi
            echo "${blu}Moving $HOME/tmp/arm-linux-androidabi-4.9 to $DIR/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9...${txtrst}"
	    mv "$HOME/tmp/arm-linux-androideabi-4.9" "$DIR/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9"
	    FCheck=$?

             if [[ $FCheck -eq 0 ]]; then
               echo "${bldcya}Toolchain arm-linux-androideabi-4.9 copied.${txtrst}"
             else
               echo "${bldred}Failed to copy toolchain arm-linux-androideabi-4.9.${txtrst}"
               exit 11
             fi

	     if [[ $no_tc2 -eq 0 && $mch_tc_bckp > 0 ]]; then
	       break
	     fi
	  fi

	  if [[ $no_tc2 -eq 1 ]]; then
            echo "${bldblu}Building arm-eabi-4.9 Toolchain because it is missing in the source code...${txtrst}"
            thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
            cd arm
	    bash arm-eabi-4.9
            FCheck=$?

              if [[ $FCheck -ne 0 ]]; then
                echo "${bldred}Failed to build arm-eabi-4.9 toolchain${txtrst}"
                exit 12
              fi
            echo "${blu}Moving $HOME/tmp/arm-gnueabi-4.9 to $DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9...${txtrst}"
            mv "$HOME/tmp/arm-linux-gnueabi-4.9" "$DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9"
            FCheck=$?

              if [[ $FCheck -eq 0 ]]; then
                echo "${bldcya}Toolchain arm-eabi-4.9 copied.${txtrst}"
              else
                echo "${bldred}Failed to copy toolchain arm-eabi-4.9.${txtrst}"
                exit 13
              fi

              if [[ $mch_tc_bckp > 0 ]]; then
	        break
	      fi
          fi
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

	  if [[ $opt_log -eq 1 || $opt_log -eq 3 ]]; then
            echo "${bldblu}Compiling toolchain $bld_tc with log (${HOME}/tc_${bld_tc}.log)${txtrst}"
            thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
	    bash $bld_tc > "$HOME/tc_$bld_tc.log"
	  else
            thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
	    bash $bld_tc
	    FCheck=$?

	      if [[ $FCheck -ne 0 ]]; then
	        echo "${bldred}Failed to build $bld_tc toolchain${txtrst}"
	        exit 14
	      fi
	  fi
	echo ""

	  if [[ $bld_tc = arm-eabi-4.9 ]]; then
            echo "${blu}Moving $HOME/tmp/arm-linux-gnueabi-4.9 to $DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9...${txtrst}"
	    mv "$HOME/tmp/arm-linux-gnueabi-4.9" "$DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9"
	    FCheck=$?
	  else
	    echo "${blu}Moving $HOME/tmp/$bld_tc to $DIR/prebuilts/gcc/linux-x86/$fldr/${bld_tc}...${txtrst}"
	    mv "$HOME/tmp/$bld_tc" "$DIR/prebuilts/gcc/linux-x86/$fldr/${bld_tc}"
	    FCheck=$?
	  fi
	echo ""

	  if [[ $FCheck -eq 0 ]]; then
	    echo "${bldcya}Toolchain $bld_tc copied.${txtrst}"
	  else
	    echo "${bldred}Failed to copy toolchain ${bld_tc}.${txtrst}"
	    exit 15
	  fi
      done
    cd "$DIR"
  fi
# Get time of startup
t1=$($DATE +%s)

# Setup environment
echo "${bldblu}Setting up environment${txtrst}"
. build/envsetup.sh &>/dev/null

  if [[ $? -eq 126 ]]; then
    echo "${bldblu}Changing build/envsetup permissions...${txtrst}"
    chmod a+x build/envsetup.sh
    . build/envsetup.sh
  fi

# Remove system folder (this will create a new build.prop with updated build time and date)
rm -f "$OUTDIR/target/product/$device/system/build.prop"
rm -f "$OUTDIR/target/product/$device/system/app/*.odex"
rm -f "$OUTDIR/target/product/$device/system/framework/*.odex"

# Start compilation

# Lunch & build device
echo ""

  if [[ $opt_log -eq 2 || $opt_log -eq 3 ]]; then
    echo "${bldblu}Compiling ROM with log (${HOME}/make_${device}.log)${txtrst}"
    lunch "px_$device-$variant" && make bacon "-j$opt_jobs" > "$HOME/make_$device.log"
  else
    echo "${bldblu}Compiling ROM${txtrst}"
    lunch "px_$device-$variant" && make bacon "-j$opt_jobs"
  fi
FCheck=$?

# Check build completion
  if [[ $FCheck -ne 0 ]]; then
    echo "${bldred}Build failed, error code: ${FCheck}${txtrst}"
    exit 16
  fi

# FTP file check
ftp_fls ()
 {
  echo ""
    if [[ -z $file ]]; then
      echo "${bldred}Error: file '$HOME/$file' is missing or empty${txtrst}"
      echo ""
      read -p "${bldblu}Enter the FTP server $ftp_usg here: ${txtrst}" ftp_tmp
      echo "$ftp_tmp" > "$HOME/$file"
    fi
      echo ""
      echo "${bldgrn}Using '$ftp_cntnt' as FTP server $file_usg${txtrst}"
 }

# Upload via FTP (-u)
  if [[ $opt_upl -eq 1 ]]; then
    # FTP server address
    file=.ftp_host
    ftp_host=$(cat "$HOME/$file" &>/dev/null)
    ftp_cntnt="$ftp_host"
    ftp_usg=address
    ftp_fls

    # FTP server username
    file=.ftp_usr
    ftp_usr=$(cat "$HOME/$file" &>/dev/null)
    ftp_cntnt="$ftp_usr"
    ftp_usg=username
    ftp_fls

    # FTP server password
    file=.ftp_passwd
    ftp_passwd=$(cat "$HOME/$file" &>/dev/null)
    ftp_cntnt="$ftp_passwd"
    ftp_usg=password
    ftp_fls

    # Start upload
    echo ""
    echo "${bldblu}Uploading '$OUTDIR/target/product/$device/$PX_VERSION' to '$ftp_host'...${txtrst}"
    curl -T "$OUTDIR/target/product/$device/$PX_VERSION" -u "$ftp_usr":"$ftp_passwd" "ftp://$ftp_host"
    FCheck=$?
    echo ""

      if [[ $FCheck -eq 0 ]]; then
        echo "${bldcya}'$PX_VERSION' uploaded to '$FTP_HOST'${txtrst}"
      else
        echo "${bldred}'$PX_VERSION' failed to upload to '$FTP_HOST', error code '$FCheck'${txtrst}"
        exit 17
      fi
  fi
# Finished? Get elapsed time
t2=$($DATE +%s)

tmin=$(( (t2-t1)/60 ))
tsec=$(( (t2-t1)%60 ))

echo "${bldgrn}Total time elapsed:${txtrst} ${grn}$tmin minutes $tsec seconds${txtrst}"
exit 0
