#!/bin/sh
#set -xue
set -x

while getopts "om:" option; do
 case $option in
  o)
   echo "Received -o flag for optional checkout of operational-only codes"
   checkout_gtg="YES"
   checkout_wafs="YES"
   ;;
  m)
   echo "Received -m flag with argument, will check out ufs-weather-model hash $OPTARG instead of default"
   ufs_model_hash=$OPTARG
   ;;
  :)
   echo "option -$OPTARG needs an argument"
   ;;
  *)
   echo "invalid option -$OPTARG, exiting..."
   exit
   ;;
 esac
done

topdir=$(pwd)
logdir="${topdir}/logs"
mkdir -p ${logdir}

echo ufs-weather-model checkout ...
if [[ ! -d ufs_model.fd ]] ; then
    git clone https://github.com/ufs-community/ufs-weather-model ufs_model.fd >> ${logdir}/checkout-ufs_model.log 2>&1
    cd ufs_model.fd
    git checkout ${ufs_model_hash:-eb42fb8b37254cf0483cd21ab4c6ccc51abe4786}
    git submodule update --init --recursive
    cd ${topdir}
else
    echo 'Skip.  Directory ufs_model.fd already exists.'
fi 

echo WW3 checkout ...
if [[ ! -d WW3.fd ]] ; then
    git clone https://github.com/noaa-emc/ww3 WW3.fd >> ${logdir}/checkout-ww3.log 2>&1
    cd WW3.fd
    git checkout aed0e737bea014664236c910c2b6a1d8097a2d93 
    cd ${topdir}
else
    echo 'Skip.  Directory WW3.fd already exists.'
fi


exit 0
