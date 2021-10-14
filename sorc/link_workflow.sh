#!/bin/ksh
set -ex

#--make symbolic links for EMC installation and hardcopies for NCO delivery

RUN_ENVIR=${1}
machine=${2}
if [ $# -eq 3 ]; then
  model=${3}
else
  model="uncoupled"
fi

if [ $# -lt 2 ]; then
    echo '***ERROR*** must specify two arguements: (1) RUN_ENVIR, (2) machine'
    echo ' Syntax: link_workflow.sh ( nco | emc ) ( cray | dell | hera | orion | jet | stampede )'
    echo ' A third argument is needed when coupled: '
    echo ' Syntax: link_workflow.sh ( nco | emc ) ( cray | dell | hera | orion | jet | stampede ) coupled'
    exit 1
fi

if [ $RUN_ENVIR != emc -a $RUN_ENVIR != nco ]; then
    echo ' Syntax: link_workflow.sh ( nco | emc ) ( cray | dell | hera | orion | jet | stampede )'
    echo ' A third argument is needed when coupled: '
    echo ' Syntax: link_workflow.sh ( nco | emc ) ( cray | dell | hera | orion | jet | stampede ) coupled'
    exit 1
fi
if [ $machine != cray -a $machine != dell -a $machine != hera -a $machine != orion -a $machine != jet -a $machine != stampede ]; then
    echo ' Syntax: link_workflow.sh ( nco | emc ) ( cray | dell | hera | orion | jet | stampede )'
    echo ' A third argument is needed when coupled: '
    echo ' Syntax: link_workflow.sh ( nco | emc ) ( cray | dell | hera | orion | jet | stampede ) coupled'
    exit 1
fi

LINK="ln -fs"
SLINK="ln -fs"
[[ $RUN_ENVIR = nco ]] && LINK="cp -rp"

pwd=$(pwd -P)

#------------------------------
#--model fix fields
#------------------------------
if [ $machine = "orion" ]; then
    FIX_DIR="/work/noaa/global/glopara/fix_NEW"
else 
   exit  
fi

if [ ! -z $FIX_DIR ]; then
 if [ ! -d ${pwd}/../fix ]; then mkdir ${pwd}/../fix; fi
fi
cd ${pwd}/../fix                ||exit 8
for dir in fix_wave 
            do
    if [ -d $dir ]; then
      [[ $RUN_ENVIR = nco ]] && chmod -R 755 $dir
      rm -rf $dir
    fi
    $LINK $FIX_DIR/$dir .
done

exit 0

