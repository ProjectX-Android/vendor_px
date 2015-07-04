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

yn_check()
{
 until [[ $yorn = y || $yorn = n ]]; do
   echo ""
   read -p "${bldred}Please enter [y/n]: ${txtrst}" yorn
 done
}

cmmnd_check()
 {
  if [[ $? -ne 0 ]]; then
    echo ""
    echo "${bldred}ERROR:${txtrst} '$cmmnd' failed"
    exit 1
  fi
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
    echo ""
    echo "${bldred}ERROR:${txtrst} No .repo directory found."
    echo "Is this an Android build tree?"
    exit 2
  fi

  if [[ ! -d vendor/px ]]; then
    echo ""
    echo "${bldred}ERROR:${txtrst} No vendor/px directory found.  Is this a ProjectX build tree?"
    exit 3
  fi

# Find the output directories
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
thisSRCDIR="${PWD##*/}"

  if [[ -z $OUT_DIR_COMMON_BASE ]]; then
    export OUTDIR="$DIR/out"
    echo ""
    echo "${blu}WARNING:${txtrst} No external out, using default ($OUTDIR)"
  else
    export OUTDIR="$OUT_DIR_COMMON_BASE"
    echo ""
    echo "${cya}External out DIR is set ($OUTDIR)"
    echo "But $OUTDIR/$thisSRCDIR will be used${txtrst}"
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

  while getopts "c:hj:l:st:u" opt; do
    case "$opt" in
      c) opt_clean="$OPTARG" ;;
      h) usage ;;
      j) opt_jobs="$OPTARG" ;;
      l) opt_log="$OPTARG" ;;
      s) opt_sync=1 ;;
      t) opt_tc=1 && mch_tc="$OPTARG" && mch_tc_bckp=$mch_tc ;;
      u) opt_upl=1 ;;
      *) echo "" && echo "${bldred}incorrect parameter${txtrst}"
	 usage ;;
    esac
  done
shift $((OPTIND-1))

device="$1"
variant="$2"

  if [[ -z $device ]]; then
    echo ""
    echo "${bldred}ERROR:${txtrst} No device specified"
    usage

  elif [[ $device -ne bacon || $device -ne m8 ]]; then
    echo ""
    echo "${bldred}WARNING:${txtrst} Invalid device specified"
    echo ""
    echo "Supported devices:"
    echo "		     - bacon (OnePlus One)"
    echo "		     - m8 (HTC One M8)"
    exit 4
  fi

  if [[ -z $variant ]]; then
    echo "${blu}WARNING:${txtrst} No build variant specified, 'user' will be used"
    variant=user
  fi

  if [[ $device = bacon ]]; then
    f_device="OnePlus One"

  elif [[ $device = m8 ]]; then
    f_device="HTC One M8"
  fi

echo "${cya}Starting ProjectX for the ${f_device}...${txtrst}"

  if [[ $opt_clean -eq 1 ]]; then
    echo ""
    echo "${bldblu}Cleaning out directory...${txtrst}"
    cmmnd="make clobber"
    make clobber &>/dev/null
    cmmnd_check
    echo "${grn}SUCCES: ${txtrst}Out is clean"

  elif [[ $opt_clean -eq 2 ]]; then
    echo ""
    echo "${bldblu}Preparing for dirty...${txtrst}"
    cmmnd="make dirty"
    make dirty &>/dev/null
    cmmnd_check
    echo "${grn}SUCCES:${txtrst} Out is dirty"

  elif [[ $opt_clean -eq 3 ]]; then
    echo ""
    echo "${bldblu}Preparing your magical adventures...${txtrst}"
    cmmnd="make magic"
    make magic &>/dev/null
    cmmnd_check
    echo "${grn}SUCCES:${txtrst} Enjoy your magical adventure"

  elif [[ $opt_clean -eq 4 ]]; then
    echo ""
    echo "${bldblu}Cleaning the kernel components....${txtrst}"
    cmmnd="make kernelclean"
    make kernelclean &>/dev/null
    cmmnd_check
    echo "${grn}SUCCES:${txtrst} All kernel components have been removed"
  fi

# Sync with latest sources
  if [[ $opt_sync -ne 0 ]]; then
    echo ""
    echo "${bldblu}Syncing repository...${txtrst}"
    cmmnd="repo sync -j$opt_jobs"
    repo sync -j$opt_jobs
    cmmnd_check
    echo "${grn}SUCCES:${txtrst} Repository synced"
  fi
rm -f "$OUTDIR/target/product/$device/obj/KERNEL_OBJ/.version"

  if [[ ! -d prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 ]]; then
    echo ""
    echo "${blu}WARNING:${txtrst} Toolchain arm-linux-androideabi-4.9 not found."
    echo ""
    echo "Do you have it backed up somewhere?"
    read -p "Enter it's path here, leave empty if you don't have it: " tc_dir

      if [[ -z $tc_dir ]]; then
	echo ""
        read -p "${blu}Do you want to build it? [y/n]: ${txtrst}" yorn
        yn_check
	echo ""

          if [[ $yorn = n ]]; then
	    echo "${blu}WARNING:${txtrst} arm-linux-androideabi-4.9 toolchain won't be built!"
          else
	    echo "${bldblu}arm-linux-androideabi-4.9 toolchain will be built!${txtrst}"
	    no_tc1=1
	    opt_tc=1
	    mch_tc=1
          fi
      else

          until [[ -d $tc_dir ]]; do
	    echo ""
	    echo "${bldred}ERROR:${txtrst} Directory not found, try again: "
	  done
	echo ""
	echo "${bldblu}Copying $tc_dir to prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9...${txtrst}"
	cp -R "$tc_dir" prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9
	echo ""
	echo "${grn}SUCCES:${txtrst} arm-linux-androideabi-4.9 copied"
      fi
  fi

  if [[ ! -d prebuilts/gcc/linux-x86/arm/arm-eabi-4.9 ]]; then
    echo ""
    echo "${blu}WARNING:${txtrst} Toolchain arm-eabi-4.9 not found."
    echo ""
    echo "${bldblu}Do you have it backed up somewhere?${txtrst}"
    read -p "${bldblu}Enter it's path here, leave empty if you haven't: ${txtrst}" tc_dir

      if [[ -z $tc_dir ]]; then
	echo ""
        read -p "${blu}Do you want to build it? [y/n]: ${txtrst}" yorn
        yn_check
	echo ""

          if [[ $yorn = n ]]; then
            echo "${blu}WARNING:${txtrst} arm-eabi-4.9 toolchain won't be built!"
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
            echo "${bldred}ERROR:${txtrst} Directory not found, try again: "
          done
        echo ""
        echo "${bldblu}Copying $tc_dir to prebuilts/gcc/linux-x86/arm/arm-eabi-4.9${txtrst}"
        cp -R "$tc_dir" prebuilts/gcc/linux-x86/arm/arm-eabi-4.9
	echo ""
	echo "${grn}SUCCES:${txtrst} arm-eabi-4.9 copied"
      fi
  fi

  if [[ $opt_tc -eq 1 ]]; then

    echo ""
    echo "${bldblu}What toolchain repository do you want to use?${txtrst}"
    read -p "${bldblu}Leave empty for default ($HOME/sm-tc): ${txtrst}" SM_dir

      if [[ -z $SM_dir ]]; then
	SM_dir=$HOME/sm-tc
      fi

      if [[ $SM_dir != $HOME/sm-tc ]]; then

	  until [[ -d $SM_dir ]]; do
	    echo ""
	    echo "${bldred}ERROR:${txtrst} The directory '$SM_dir' doesn't exist, try again"
	    read -p "Leave empty for default ($HOME/sm-tc): " SM_dir
	  done

      elif [[ ! -d $SM_dir ]]; then
	echo ""
        echo "${blu}WARNING:${txtrst} Directory '$HOME/sm-tc' not found, creating it..."
        mkdir -p "$HOME/sm-tc"
        opt_init=1
      fi

      if [[ ! -d $SM_dir/.repo && opt_init -ne 1 ]]; then
	echo ""
        echo "${blu}WARNING:${txtrst} No repo initialized in '$HOME/sm-tc' Initializing now..."
        opt_init=1

      elif [[ ! -d $SM_dir/smbuild ]]; then
	echo ""
	echo "${bldred}ERROR:${txtrst} Is this a SaberMod build tree?"
	exit 6
      fi
    cd "$SM_dir"
      if [[ $opt_init -eq 1 ]]; then
	cmmnd="repo init -u https://gitlab.com/SaberMod/sabermod-manifest.git -b master"
        repo init -u https://gitlab.com/SaberMod/sabermod-manifest.git -b master
	cmmnd_check
	echo "${grn}SUCCES:${txtrst} Repo initialized"
      fi
    echo ""
    echo "${bldgrn}Syncing with the SaberMod repo...${txtrst}"
    cmmnd="repo sync"
    repo sync
    cmmnd_check
    echo "${grn}SUCCES:${txtrst} Repo synced"

    cd smbuild
    shft_tc=0

      until [[ $shft_tc -eq $mch_tc ]]; do
	  if [[ $no_tc1 -eq 1 ]]; then
	    echo ""
	    echo "${blu}WARNING:${txtrst} Building arm-linux-androideabi-4.9 Toolchain because it is missing in the source code..."
	    thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
            cd arm
	    cmmnd="bash arm-linux-androideabi-4.9"
	    bash arm-linux-androideabi-4.9
	    cmmnd_check
	    echo ""
	    echo "${grn}SUCCES:${txtrst} arm-linux-androideabi-4.9 toolchain built"

	    echo ""
            echo "${blu}Moving $HOME/tmp/arm-linux-androidabi-4.9 to $DIR/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9...${txtrst}"
	    cmmnd="mv $HOME/tmp/arm-linux-androideabi-4.9 $DIR/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9"
	    mv "$HOME/tmp/arm-linux-androideabi-4.9" "$DIR/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9"
	    cmmnd_check
	    echo ""
            echo "${grn}SUCCES:${txtrst} Toolchain arm-linux-androideabi-4.9 copied"

	     if [[ $no_tc2 -eq 0 && $mch_tc_bckp > 0 ]]; then
	       break
	     fi
	  fi

	  if [[ $no_tc2 -eq 1 ]]; then
	    echo ""
            echo "${blu}WARNING:${txtrst} Building arm-eabi-4.9 Toolchain because it is missing in the source code..."
            thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
            cd arm
	    cmmnd="bash arm-eabi-4.9"
	    bash arm-eabi-4.9
            cmmnd_check
            echo "${grn}SUCCES:${txtrst} arm-linux-androideabi-4.9 toolchain built"

            echo "${blu}Moving $HOME/tmp/arm-gnueabi-4.9 to $DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9...${txtrst}"
	    cmmnd="mv $HOME/tmp/arm-linux-gnueabi-4.9 $DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9"
            mv "$HOME/tmp/arm-linux-gnueabi-4.9" "$DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9"
	    cmmnd_check
	    echo ""
            echo "${grn}SUCCES:${txtrst} Toolchain arm-eabi-4.9 copied"

              if [[ $mch_tc_bckp > 0 ]]; then
	        break
	      fi
          fi
	shft_tc=$(( shft_tc + 1 ))
        echo ""
	read -p "${bldblu}Enter toolchain ${shft_tc}'s name (ex. arm-eabi-4.9): ${txtrst}" bld_tc
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
	    echo ""
            echo "${bldblu}Compiling toolchain $bld_tc with log (${HOME}/tc_${bld_tc}.log)${txtrst}"
            thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
	    bash $bld_tc > "$HOME/tc_$bld_tc.log"
	  else
            thisSMDIR="${PWD##*/}"
            rm -R /tmp/$thisSMDIR
	    cmmnd="bash $bld_tc"
	    bash $bld_tc
	    cmmnd_check
	    echo ""
	    echo "${grn}SUCCES:${txtrst} $bld_tc built"
	  fi
	echo ""

	  if [[ $bld_tc = arm-eabi-4.9 ]]; then
            echo "${blu}Moving $HOME/tmp/arm-linux-gnueabi-4.9 to $DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9...${txtrst}"
	    cmmnd="mv $HOME/tmp/arm-linux-gnueabi-4.9 $DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9"
	    mv "$HOME/tmp/arm-linux-gnueabi-4.9" "$DIR/prebuilts/gcc/linux-x86/arm/arm-eabi-4.9"
	    cmmnd_check
	    echo "${grn}SUCCES:${txtrst} arm-eabi-4.9 toolchain copied"
	  else
	    echo "${blu}Moving $HOME/tmp/$bld_tc to $DIR/prebuilts/gcc/linux-x86/$fldr/${bld_tc}...${txtrst}"
	    cmmnd="mv $HOME/tmp/$bld_tc $DIR/prebuilts/gcc/linux-x86/$fldr/$bld_tc"
	    mv "$HOME/tmp/$bld_tc" "$DIR/prebuilts/gcc/linux-x86/$fldr/$bld_tc"
	    cmmnd_check
            echo "${grn}SUCCES:${txtrst} $bld_tc toolchain copied"
	  fi
      done
    cd "$DIR"
  fi
# Get time of startup
t1=$($DATE +%s)

# Setup environment
echo ""
echo "${bldblu}Setting up environment${txtrst}"
. build/envsetup.sh &>/dev/null

  if [[ $? -eq 126 ]]; then
    echo ""
    echo "${bldblu}Changing build/envsetup permissions...${txtrst}"
    chmod a+x build/envsetup.sh
    . build/envsetup.sh &>/dev/null
  fi
lunch "px_${device}-$variant"
echo "${grn}SUCCES:${txtrst} Environment setup succesfully"

# Remove system folder (this will create a new build.prop with updated build time and date)
rm -f "$OUTDIR/target/product/$device/system/build.prop"
rm -f "$OUTDIR/target/product/$device/system/app/*.odex"
rm -f "$OUTDIR/target/product/$device/system/framework/*.odex"

# Start compiling
echo ""

  if [[ $opt_log -eq 2 || $opt_log -eq 3 ]]; then
    echo "${bldblu}Compiling ProjectX for the $f_device with log (${HOME}/make_${device}.log)${txtrst}"
    cmmnd="make bacon -j$opt_jobs > $HOME/make_$device.log"
    make bacon "-j$opt_jobs" > "$HOME/make_$device.log"
    cmmnd_check
    echo "${grn}SUCCES:${txtrst} Build completed"
  else
    echo "${bldblu}Compiling ProjectX for the $f_device ${txtrst}"
    cmmnd="make bacon -j$opt_jobs"
    make bacon "-j$opt_jobs"
    cmmnd_check
    echo "${grn}SUCCES:${txtrst} Build completed"
  fi

# FTP file check
ftp_fls ()
 {
  echo ""
    if [[ -z $file ]]; then
      echo "${bldred}ERROR:${txtrst} File '$HOME/$file' is missing or empty"
      echo ""
      read -p "${bldblu}Enter the FTP server $ftp_usg here: ${txtrst}" ftp_tmp
      echo "$ftp_tmp" > "$HOME/$file"
    fi
      echo ""
      echo "${grn}SUCCES:${txtrst} Using '$ftp_cntnt' as FTP server $file_usg"
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
    cmmnd="curl -T $OUTDIR/target/product/$device/$PX_VERSION -u $ftp_usr:$ftp_passwd ftp://$ftp_host"
    curl -T "$OUTDIR/target/product/$device/$PX_VERSION" -u "$ftp_usr":"$ftp_passwd" "ftp://$ftp_host"
    cmmnd_check
    echo ""
    echo "${grn}SUCCES:${txtrst} '$PX_VERSION' uploaded to '$FTP_HOST'"
  fi
# Finished? Get elapsed time
t2=$($DATE +%s)

tmin=$(( (t2-t1)/60 ))
tsec=$(( (t2-t1)%60 ))

echo ""
echo "${bldcya}Total time elapsed:${txtrst} ${grn}$tmin minutes $tsec seconds${txtrst}"
exit 0
