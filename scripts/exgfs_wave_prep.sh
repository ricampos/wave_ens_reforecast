#!/bin/bash
#
################################################################################
#
# UNIX Script Documentation Block
# Script name:         exwave_prep.sh
# Script description:  Creates output products from binary WW3 data
#
# Author:   Hendrik Tolman      Org: NCEP/EMC      Date: 2007-03-01
# Abstract: This is the preprocessor for the wave component in GFS.
#           It executes several scripts for preparing and creating input data
#           as follows:
#                                                                             
#  wave_prnc_ice.sh     : preprocess ice fields.                              #
#  wave_prnc_wnd.sh     : preprocess wind fields (uncoupled run, not active)  #
#  wave_prnc_cur.sh     : preprocess current fields.                          #
#  wave_g2ges.sh  : find and copy wind grib2 files.                           #
#                                                                             #
# Remarks :                                                                   #
# - For non-fatal errors output is witten to the wave.log file.               #
#                                                                             #
#  Update record :                                                            #
#                                                                             #
# - Origination:                                               01-Mar-2007    #
#                                                                             #
# Update log                                                                  #
# Mar2007 HTolman - Added NCO note on resources on mist/dew                   #
# Apr2007 HTolman - Renaming mod_def files in $FIX_wave.                      #
# Mar2011 AChawla - Migrating to a vertical structure                         #
# Nov2012 JHAlves - Transitioning to WCOSS                                    #
# Apr2019 JHAlves - Transitioning to GEFS workflow                            #
# Nov2019 JHAlves - Merging wave scripts to global workflow                   #
# Jun2020 JHAlves - Porting to R&D machine Hera                               #
# Oct2020 JMeixner - Updating RTOFS dates for processing minimal amount       #
#                                                                             #
#   WAV_MOD_ID and WAV_MOD_TAG replace modID. WAV_MOD_TAG                     # 
#   is used for ensemble-specific I/O. For deterministic                      #
#   WAV_MOD_ID=WAV_MOD_TAG                                                    # 
#                                                                             #
###############################################################################
# --------------------------------------------------------------------------- #
# 0.  Preparations
# 0.a Basic modes of operation

  set -x
  # Use LOUD variable to turn on/off trace.  Defaults to YES (on).
  export LOUD=${LOUD:-YES}; [[ $LOUD = yes ]] && export LOUD=YES
  [[ "$LOUD" != YES ]] && set +x

  # Set wave model ID tag to include member number
  # if ensemble; waveMEMB var empty in deterministic
  export WAV_MOD_TAG=${CDUMP}wave${waveMEMB}

  cd $DATA
  mkdir outtmp

  echo "HAS BEGUN on $(hostname)"
  echo "Starting MWW3 PREPROCESSOR SCRIPT for $WAV_MOD_TAG"

  set +x
  echo ' '
  echo '                      ********************************'
  echo '                      *** MWW3 PREPROCESSOR SCRIPT ***'
  echo '                      ********************************'
  echo '                          PREP for wave component of NCEP coupled system'
  echo "                          Wave component identifier : $WAV_MOD_TAG "
  echo ' '
  echo "Starting at : $(date)"
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  #  export MP_PGMMODEL=mpmd
  #  export MP_CMDFILE=./cmdfile

  if [ "$INDRUN" = 'no' ]
  then
    FHMAX_WAV=${FHMAX_WAV:-3}
  else
    FHMAX_WAV=${FHMAX_WAV:-384}
  fi

  # 0.b Date and time stuff

  # Beginning time for outpupt may differ from SDATE if DOIAU=YES
  export date=$PDY
  export YMDH=${PDY}${cyc}
  # Roll back $IAU_FHROT hours of DOIAU=YES
  IAU_FHROT=3
  if [ "$DOIAU" = "YES" ]
  then
    WAVHINDH=$(( WAVHINDH + IAU_FHROT ))
  fi
  # Set time stamps for model start and output
  # For special case when IAU is on but this is an initial half cycle 
  if [ $IAU_OFFSET = 0 ]; then
    ymdh_beg=$YMDH
  else
    ymdh_beg=$($NDATE -$WAVHINDH $YMDH)
  fi
  time_beg="$(echo $ymdh_beg | cut -c1-8) $(echo $ymdh_beg | cut -c9-10)0000"
  ymdh_end=$($NDATE $FHMAX_WAV $YMDH)
  time_end="$(echo $ymdh_end | cut -c1-8) $(echo $ymdh_end | cut -c9-10)0000"
  ymdh_beg_out=$YMDH
  time_beg_out="$(echo $ymdh_beg_out | cut -c1-8) $(echo $ymdh_beg_out | cut -c9-10)0000"

  # Restart file times (already has IAU_FHROT in WAVHINDH) 
  RSTOFFSET=$(( ${WAVHCYC} - ${WAVHINDH} ))
  # Update restart time is added offset relative to model start
  RSTOFFSET=$(( ${RSTOFFSET} + ${RSTIOFF_WAV} ))
  ymdh_rst_ini=$($NDATE ${RSTOFFSET} $YMDH)
  RST2OFFSET=$(( DT_2_RST_WAV / 3600 ))
  ymdh_rst2_ini=$($NDATE ${RST2OFFSET} $YMDH) # DT2 relative to first-first-cycle restart file
  # First restart file for cycling
  time_rst_ini="$(echo $ymdh_rst_ini | cut -c1-8) $(echo $ymdh_rst_ini | cut -c9-10)0000"
  if [ ${DT_1_RST_WAV} = 1 ]; then
    time_rst1_end=${time_rst_ini}
  else
    RST1OFFSET=$(( DT_1_RST_WAV / 3600 ))
    ymdh_rst1_end=$($NDATE $RST1OFFSET $ymdh_rst_ini)
    time_rst1_end="$(echo $ymdh_rst1_end | cut -c1-8) $(echo $ymdh_rst1_end | cut -c9-10)0000"
  fi
  # Second restart file for checkpointing
  if [ "${RSTTYPE_WAV}" = "T" ]; then
    time_rst2_ini="$(echo $ymdh_rst2_ini | cut -c1-8) $(echo $ymdh_rst2_ini | cut -c9-10)0000"
    time_rst2_end=$time_end
  # Condition for gdas run or any other run when checkpoint stamp is > ymdh_end
    if [ $ymdh_rst2_ini -ge $ymdh_end ]; then
      ymdh_rst2_ini=$($NDATE 3 $ymdh_end)
      time_rst2_ini="$(echo $ymdh_rst2_ini | cut -c1-8) $(echo $ymdh_rst2_ini | cut -c9-10)0000"
      time_rst2_end=$time_rst2_ini
    fi
  else
    time_rst2_ini="$"
    time_rst2_end=
    DT_2_RST_WAV=
  fi
  set +x
  echo ' '
  echo 'Times in wave model format :'
  echo '----------------------------'
  echo "   date / cycle  : $date $cycle"
  echo "   starting time : $time_beg"
  echo "   ending time   : $time_end"
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  # Script will run only if pre-defined NTASKS
  #     The actual work is distributed over these tasks.
  if [ -z ${NTASKS} ]        
  then
    echo "FATAL ERROR: Requires NTASKS to be set "
    err=1; export err;${errchk}
  fi

  # --------------------------------------------------------------------------- #
  # 1.  Get files that are used by most child scripts

  set +x
  echo 'Preparing input files :'
  echo '-----------------------'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  # 1.a Model definition files

  rm -f cmdfile
  touch cmdfile

  grdINP=''
  if [ "${WW3ATMINP}" = 'YES' ]; then grdINP="${grdINP} $WAVEWND_FID" ; fi 
  if [ "${WW3ICEINP}" = 'YES' ]; then grdINP="${grdINP} $WAVEICE_FID" ; fi 
  if [ "${WW3CURINP}" = 'YES' ]; then grdINP="${grdINP} $WAVECUR_FID" ; fi 

  ifile=1

  for grdID in $grdINP $waveGRD
  do
    if [ -f "$COMIN/rundata/${CDUMP}wave.mod_def.${grdID}" ]
    then
      set +x
      echo " Mod def file for $grdID found in ${COMIN}/rundata. copying ...."
      [[ "$LOUD" = YES ]] && set -x
      cp $COMIN/rundata/${CDUMP}wave.mod_def.${grdID} mod_def.$grdID

    else
      set +x
      echo ' '
      echo '*********************************************************** '
      echo '*** FATAL ERROR : NOT FOUND WAVE  MODEL DEFINITION FILE *** '
      echo '*********************************************************** '
      echo "                                grdID = $grdID"
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      err=2;export err;${errchk}
    fi
  done

  # 1.b Netcdf Preprocessor template files
   if [ "$WW3ATMINP" = 'YES' ]; then itype="$itype wind" ; fi 
   if [ "$WW3ICEINP" = 'YES' ]; then itype="$itype ice" ; fi 
   if [ "$WW3CURINP" = 'YES' ]; then itype="$itype cur" ; fi 

   for type in $itype
   do

     case $type in
       wind )
         grdID=$WAVEWND_FID
       ;;
       ice )
         grdID=$WAVEICE_FID 
       ;;
       cur )
         grdID=$WAVECUR_FID 
       ;;
       * )
              echo 'Input type not yet implemented' 	    
              err=3; export err;${errchk}
              ;;
     esac 

     if [ -f $PARMwave/ww3_prnc.${type}.$grdID.inp.tmpl ]
     then
       cp $PARMwave/ww3_prnc.${type}.$grdID.inp.tmpl .
     fi

     if [ -f ww3_prnc.${type}.$grdID.inp.tmpl ]
     then
       set +x
       echo ' '
       echo "   ww3_prnc.${type}.$grdID.inp.tmpl copied ($PARMwave)."
       echo ' '
       [[ "$LOUD" = YES ]] && set -x
     else
       set +x
       echo ' '
       echo '************************************** '
       echo '*** FATAL ERROR : NO TEMPLATE FILE *** '
       echo '************************************** '
       echo "             ww3_prnc.${type}.$grdID.inp.tmpl"
       echo ' '
       echo ' '
       [[ "$LOUD" = YES ]] && set -x
       err=4;export err;${errchk}
     fi
   done

# --------------------------------------------------------------------------- #
# ICEC processing

  if [ "${WW3ICEINP}" = 'YES' ]; then

# --------------------------------------------------------------------------- #
# 2. Ice pre - processing 

# 2.a Check if ice input is perturbed (number of inputs equal to number of wave
#     ensemble members
    if [ "${RUNMEM}" = "-1" ] || [ "${WW3ICEIENS}" = "T" ] || [ "$waveMEMB" = "00" ]
    then

      $USHwave/wave_prnc_ice.sh > wave_prnc_ice.out 
      ERR=$?
    
      if [ -d ice ]
      then
        set +x
        echo ' '
        echo '      FATAL ERROR: ice field not generated '
        echo ' '
        sed "s/^/wave_prnc_ice.out : /g" wave_prnc_ice.out
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        err=5;export err;${errchk}
      else
        mv -f wave_prnc_ice.out $DATA/outtmp
        set +x
        echo ' '
        echo '      Ice field unpacking successful.'
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      fi
    else
      echo ' '
      echo "WARNING: Ice input is not perturbed, single ice file generated, skipping ${WAV_MOD_TAG}"
      echo ' '
    fi 
  else
      echo ' '
      echo 'WARNING: No input ice file generated, this run did not request pre-processed ice data '
      echo ' '
  fi

# --------------------------------------------------------------------------- #
# WIND processing 
# This block of code is not used by GFSv16b and is here for un-coupled wave runs
  if [ "${WW3ATMINP}" = 'YES' ]; then

# --------------------------------------------------------------------------- #
# 3.  Wind pre-processing

    if [ "${RUNMEM}" = "-1" ] || [ "${WW3ATMIENS}" = "T" ] || [ "$waveMEMB" = "00" ]
    then
 
      rm -f cmdfile
      touch cmdfile
      chmod 744 cmdfile
 
# 3.a Gather and pre-process grib2 files 
      ymdh=$ymdh_beg
    
      if [ ${CFP_MP:-"NO"} = "YES" ]; then nm=0 ; fi # Counter for MP CFP
      while [ "$ymdh" -le "$ymdh_end" ]
      do
        if [ ${CFP_MP:-"NO"} = "YES" ]; then
          echo "$nm $USHwave/wave_g2ges.sh $ymdh > grb_$ymdh.out 2>&1" >> cmdfile
          nm=$(expr $nm + 1)
        else
          echo "$USHwave/wave_g2ges.sh $ymdh > grb_$ymdh.out 2>&1" >> cmdfile
        fi
        ymdh=$($NDATE $WAV_WND_HOUR_INC $ymdh)
      done
  
# 3.b Execute the serial or parallel cmdfile

# Set number of processes for mpmd
      cat cmdfile

      wavenproc=$(wc -l cmdfile | awk '{print $1}')
      wavenproc=$(echo $((${wavenproc}<${NTASKS}?${wavenproc}:${NTASKS})))
  
      set +x
      echo ' '
      echo "   Executing the wnd grib cmd file at : $(date)"
      echo '   ------------------------------------'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
  
      if [ "$wavenproc" -gt '1' ]
      then
        if [ ${CFP_MP:-"NO"} = "YES" ]; then
          ${wavempexec} -n ${wavenproc} ${wave_mpmd} cmdfile
        else
          ${wavempexec} ${wavenproc} ${wave_mpmd} cmdfile
        fi
        exit=$?
      else
        ./cmdfile
        exit=$?
      fi
  
      if [ "$exit" != '0' ]
      then
        set +x
        echo ' '
        echo '********************************************************'
        echo '*** FATAL ERROR: CMDFILE FAILED IN WIND GENERATION   ***'
        echo '********************************************************'
        echo '     See Details Below '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      fi
   
# 3.c Check for errors
  
      set +x
      echo ' '
      echo '   Checking for errors.'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
    
#     We will go on if the number of errors in files is less
#     than err_max

      [[ "$LOUD" = YES ]] && set -x
      err_max=1
  
  
      ymdh=$ymdh_beg
      nr_err=0

      set +x
      echo '      Sources of grib2 files :'
      [[ "$LOUD" = YES ]] && set -x
      while [ "$ymdh" -le "$ymdh_end" ]
      do
        if [ -d grb_${ymdh} ]
        then
          set +x
          echo ' '
          echo "         File for $ymdh : error in wave_g2ges.sh"
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          nr_err=$(expr $nr_err + 1)
          rm -f gwnd.$ymdh
        else
          grbfile=$(grep 'File for' grb_${ymdh}.out)
          if [ -z "$grbfile" ]
          then
            set +x
            echo ' '
            echo "         File for $ymdh : cannot identify source"
            echo ' '
            [[ "$LOUD" = YES ]] && set -x
            nr_err=$(expr $nr_err + 1)
            rm -f gwnd.$ymdh
          else
            if [ ! -f gwnd.$ymdh ]
            then
              set +x
              echo ' '
              echo "         File for $ymdh : file not found"
              echo ' '
              [[ "$LOUD" = YES ]] && set -x
              nr_err=$(expr $nr_err + 1)
            else
              set +x
              echo ' '
              echo "      $grbfile"
              echo ' '
              [[ "$LOUD" = YES ]] && set -x
              mv -f grb_${ymdh}.out $DATA/outtmp
            fi
          fi
        fi
        ymdh=$($NDATE $WAV_WND_HOUR_INC $ymdh)
      done

      if [ -f grb_*.out ]
      then
        set +x
        echo ' '
        echo '**********************************'
        echo '*** ERROR OUTPUT wave_g2ges.sh ***'
        echo '**********************************'
        echo '            Possibly in multiple calls'
        [[ "$LOUD" = YES ]] && set -x
        set +x
        for file in grb_*.out
        do
          echo ' '
          sed "s/^/$file : /g" $file
        done
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        mv -f grb_*.out $DATA/outtmp
      fi
    
      if [ "$nr_err" -gt "$err_max" ]
      then
        set +x
        echo ' '
        echo '********************************************* '
        echo '*** FATAL ERROR : ERROR(S) IN WIND  FILES *** '
        echo '********************************************* '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        err=6;export err;${errchk}
      fi
  
      rm -f cmdfile

# 3.d Getwind data into single file 

      set +x
      echo ' '
      echo '   Concatenate extracted wind fields ...'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x

      files=$(ls gwnd.* 2> /dev/null)

      if [ -z "$files" ]
      then
        set +x
        echo ' '
        echo '******************************************** '
        echo '*** FATAL ERROR : CANNOT FIND WIND FILES *** '
        echo '******************************************** '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        err=7;export err;${errchk}
      fi
  
      rm -f gfs.wind
  
      for file in $files
      do
        cat $file >> gfs.wind
        rm -f $file
      done
  
# 3.e Run ww3_prnc

# Convert gfs wind to netcdf
      $WGRIB2 gfs.wind -netcdf gfs.nc
  
      for grdID in $WAVEWND_FID $curvID
      do
  
        set +x
        echo ' '
        echo "   Running wind fields through preprocessor for grid $grdID"
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
  
        sed -e "s/HDRFL/T/g" ww3_prnc.wind.$grdID.tmpl > ww3_prnc.inp
        ln -sf mod_def.$grdID mod_def.ww3
  
        set +x
        echo "Executing $EXECwave/ww3_prnc"
        [[ "$LOUD" = YES ]] && set -x
  
        $EXECwave/ww3_prnc > prnc.out
        err=$?
  
        if [ "$err" != '0' ]
        then
          set +x
          echo ' '
          echo '*************************************** '
          echo '*** FATAL ERROR : ERROR IN waveprnc *** '
          echo '*************************************** '
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          err=8;export err;${errchk}
        fi
  
        if [ ! -f wind.ww3 ]
        then
          set +x
          echo ' '
          cat waveprep.out
          echo ' '
          echo '****************************************'
          echo '*** FATAL ERROR : wind.ww3 NOT FOUND ***'
          echo '****************************************'
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          err=9;export err;${errchk}
        fi

        rm -f mod_def.ww3
        rm -f ww3_prep.inp

        mv wind.ww3 wind.$grdID
        mv times.WND times.$grdID

# 3.f Check to make sure wind files are properly incremented

        first_pass='yes'
        windOK='yes'
        while read line
        do
          date1=$(echo $line | cut -d ' ' -f 1)
          date2=$(echo $line | cut -d ' ' -f 2)
          ymdh="$date1$(echo $date2 | cut -c1-2)"
          if [ "$first_pass" = 'no' ]
          then
            hr_inc=$($NHOUR $ymdh $ymdh_prev)
            if [ "${hr_inc}" -gt "${WAV_WND_HOUR_INC}" ]
            then
              set +x
              echo "Incorrect wind forcing increment at $ymdh" 
              [[ "$LOUD" = YES ]] && set -x
              windOK='no'
            fi
          fi
          ymdh_prev=$ymdh
          first_pass='no'
        done < times.$grdID
  
        if [ "$windOK" = 'no' ]
        then
          set +x
          echo ' '
          echo '******************************************************'
          echo '*** FATAL ERROR : WIND DATA INCREMENT INCORRECT !! ***'
          echo '******************************************************'
          echo ' '
          [[ "$LOUD" = YES ]] && set -x
          err=10;export err;${errchk}
        fi
    
      done

      rm -f gfs.wind
      rm -f mod_def.ww3
      rm -f ww3_prnc.inp
    else
      echo ' '
      echo " Wind input is not perturbed, single wnd file generated, skipping ${WAV_MOD_TAG}"
      echo ' '

    fi

  else

      echo ' '
      echo ' Atmospheric inputs not generated, this run did not request pre-processed winds '
      echo ' '
  
  fi

#-------------------------------------------------------------------
# CURR processing 

  if [ "${WW3CURINP}" = 'YES' ]; then

#-------------------------------------------------------------------
# 4.  Process current fields
# 4.a Get into single file 
    if [ "${RUNMEM}" = "-1" ] || [ "${WW3CURIENS}" = "T" ] || [ "$waveMEMB" = "00" ]
    then

      set +x
      echo ' '
      echo '   Concatenate binary current fields ...'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x

# Prepare files for cfp process
      rm -f cmdfile
      touch cmdfile
      chmod 744 cmdfile

      ymdh_rtofs=${RPDY}00 # RTOFS runs once daily use ${PDY}00
      if [ "$ymdh_beg" -lt "$ymdh_rtofs" ];then 
         #If the start time is before the first hour of RTOFS, use the previous cycle
         export RPDY=$($NDATE -24 ${RPDY}00 | cut -c1-8)
      fi 
      #Set the first time for RTOFS files to be the beginning time of simulation
      ymdh_rtofs=$ymdh_beg      

      if [  "$FHMAX_WAV_CUR" -le 72 ]; then 
        rtofsfile1=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f024_prog.nc
        rtofsfile2=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f048_prog.nc
        rtofsfile3=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f072_prog.nc
        if [ ! -f $rtofsfile1 ] || [ ! -f $rtofsfile2 ] || [ ! -f $rtofsfile3 ]; then 
           #Needed current files are not available, so use RTOFS from previous day 
           export RPDY=$($NDATE -24 ${RPDY}00 | cut -c1-8)
        fi 
      else
        rtofsfile1=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f096_prog.nc   
        rtofsfile2=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f120_prog.nc
        rtofsfile3=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f144_prog.nc
        rtofsfile4=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f168_prog.nc
        rtofsfile5=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}/rtofs_glo_2ds_f192_prog.nc
        if [ ! -f $rtofsfile1 ] || [ ! -f $rtofsfile2 ] || [ ! -f $rtofsfile3 ] ||
            [ ! -f $rtofsfile4 ] || [ ! -f $rtofsfile5 ]; then
            #Needed current files are not available, so use RTOFS from previous day 
            export RPDY=$($NDATE -24 ${RPDY}00 | cut -c1-8)
        fi
      fi

      export COMIN_WAV_CUR=$COMIN_WAV_RTOFS/${WAVECUR_DID}.${RPDY}

      ymdh_end_rtofs=$($NDATE ${FHMAX_WAV_CUR} ${RPDY}00)
      if [ "$ymdh_end" -lt "$ymdh_end_rtofs" ]; then 
         ymdh_end_rtofs=$ymdh_end
      fi

      NDATE_DT=${WAV_CUR_HF_DT}
      FLGHF='T'
      FLGFIRST='T'
      fext='f'
  
      if [ ${CFP_MP:-"NO"} = "YES" ]; then nm=0 ; fi # Counter for MP CFP
      while [ "$ymdh_rtofs" -le "$ymdh_end_rtofs" ]
      do
        # Timing has to be made relative to the single 00z RTOFS cycle for RTOFS PDY (RPDY)
        # Start at first fhr for 
        fhr_rtofs=$(${NHOUR} ${ymdh_rtofs} ${RPDY}00)
        fh3_rtofs=$(printf "%03d" "${fhr_rtofs#0}")

        curfile1h=${COMIN_WAV_CUR}/rtofs_glo_2ds_${fext}${fh3_rtofs}_prog.nc
        curfile3h=${COMIN_WAV_CUR}/rtofs_glo_2ds_${fext}${fh3_rtofs}_prog.nc

        if [ -s ${curfile1h} ]  && [ "${FLGHF}" = "T" ] ; then
          curfile=${curfile1h}
        elif [ -s ${curfile3h} ]; then
          curfile=${curfile3h}
          FLGHF='F'
        else
          echo ' '
          if [ "${FLGHF}" = "T" ] ; then
             curfile=${curfile1h}
          else 
             curfile=${curfile3h}
          fi
          set $setoff
          echo ' '
          echo '************************************** '
          echo "*** FATAL ERROR: NO CUR FILE $curfile ***  "
          echo '************************************** '
          echo ' '
          set $seton
          err=11;export err;${errchk}
          exit $err
          echo ' '
        fi

        if [ ${CFP_MP:-"NO"} = "YES" ]; then
          echo "$nm $USHwave/wave_prnc_cur.sh $ymdh_rtofs $curfile $fhr_rtofs $FLGFIRST > cur_$ymdh_rtofs.out 2>&1" >> cmdfile
          nm=$(expr $nm + 1)
        else
          echo "$USHwave/wave_prnc_cur.sh $ymdh_rtofs $curfile $fhr_rtofs $FLGFIRST > cur_$ymdh_rtofs.out 2>&1" >> cmdfile
        fi

        if [ "${FLGFIRST}" = "T" ] ; then
            FLGFIRST='F'
        fi 

        if [ $fhr_rtofs -ge ${WAV_CUR_HF_FH} ] ; then
          NDATE_DT=${WAV_CUR_DT}
        fi
        ymdh_rtofs=$($NDATE $NDATE_DT $ymdh_rtofs)
      done

# Set number of processes for mpmd
      wavenproc=$(wc -l cmdfile | awk '{print $1}')
      wavenproc=$(echo $((${wavenproc}<${NTASKS}?${wavenproc}:${NTASKS})))

      set +x
      echo ' '
      echo "   Executing the curr prnc cmdfile at : $(date)"
      echo '   ------------------------------------'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x

      if [ $wavenproc -gt '1' ]
      then
        if [ ${CFP_MP:-"NO"} = "YES" ]; then
          ${wavempexec} -n ${wavenproc} ${wave_mpmd} cmdfile
        else
          ${wavempexec} ${wavenproc} ${wave_mpmd} cmdfile
        fi
        exit=$?
      else
        chmod 744 ./cmdfile
        ./cmdfile
        exit=$?
      fi

      if [ "$exit" != '0' ]
      then
        set +x
        echo ' '
        echo '********************************************'
        echo '*** CMDFILE FAILED IN CUR GENERATION   ***'
        echo '********************************************'
        echo '     See Details Below '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      fi

      files=$(ls ${WAVECUR_DID}.* 2> /dev/null)

      if [ -z "$files" ]
      then
        set +x
        echo ' '
        echo '******************************************** '
        echo '*** FATAL ERROR : CANNOT FIND CURR FILES *** '
        echo '******************************************** '
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
        err=11;export err;${errchk}
      fi

      rm -f cur.${WAVECUR_FID}

      for file in $files
      do
        echo $file
        cat $file >> cur.${WAVECUR_FID}
      done

      cp -f cur.${WAVECUR_FID} ${COMOUT}/rundata/${CDUMP}wave.${WAVECUR_FID}.$cycle.cur 

    else
      echo ' '
      echo " Current input is not perturbed, single cur file generated, skipping ${WAV_MOD_TAG}"
      echo ' '
    fi

  else
  
      echo ' '
      echo ' Current inputs not generated, this run did not request pre-processed currents '
      echo ' '

  fi

# --------------------------------------------------------------------------- #
# 5. Create ww3_multi.inp

# 5.a ww3_multi template

  if [ -f $PARMwave/ww3_multi.${NET}.inp.tmpl ]
  then
    cp $PARMwave/ww3_multi.${NET}.inp.tmpl ww3_multi.inp.tmpl
  fi

  if [ ! -f ww3_multi.inp.tmpl ]
  then
    set +x
    echo ' '
    echo '************************************************ '
    echo '*** FATAL ERROR : NO TEMPLATE FOR INPUT FILE *** '
    echo '************************************************ '
    echo ' '
    [[ "$LOUD" = YES ]] && set -x
    err=12;export err;${errchk}
  fi

# 5.b Buoy location file

  if [ -f $PARMwave/wave_${NET}.buoys ]
  then
    cp $PARMwave/wave_${NET}.buoys buoy.loc
  fi

  if [ -f buoy.loc ]
  then
    set +x
    echo "   buoy.loc copied ($PARMwave/wave_${NET}.buoys)."
    [[ "$LOUD" = YES ]] && set -x
  else
    set +x
    echo "   buoy.loc not found.                           **** WARNING **** "
    [[ "$LOUD" = YES ]] && set -x
    touch buoy.loc
    err=13;export err;${errchk}
  fi

# Initialize inp file parameters
  NFGRIDS=0
  NMGRIDS=0
  CPLILINE='$'
  ICELINE='$'
  ICEFLAG='no'
  CURRLINE='$'
  CURRFLAG='no'
  WINDLINE='$'
  WINDFLAG='no'
  UNIPOINTS='$'

# Check for required inputs and coupling options
  if [ $waveuoutpGRD ]
  then
    UNIPOINTS="'$waveuoutpGRD'"
  fi

# Check if waveesmfGRD is set
  if [ ${waveesmfGRD} ]
  then
    NFGRIDS=$(expr $NFGRIDS + 1)
  fi 

  case ${WW3ATMINP} in
    'YES' )
      NFGRIDS=$(expr $NFGRIDS + 1)
      WINDLINE="  '$WAVEWND_FID'  F F T F F F F F F"
      WINDFLAG="$WAVEWND_FID"
    ;;
    'CPL' )
      WNDIFLAG='T'
      if [ ${waveesmfGRD} ]
      then
        WINDFLAG="CPL:${waveesmfGRD}"
        CPLILINE="  '${waveesmfGRD}' F F T F F F F F F"
      else 
        WINDFLAG="CPL:native"
      fi
    ;;
  esac
  
  case ${WW3ICEINP} in
    'YES' ) 
      NFGRIDS=$(expr $NFGRIDS + 1)
      ICEIFLAG='T'
      ICELINE="  '$WAVEICE_FID'  F F F T F F F F F"
      ICEFLAG="$WAVEICE_FID"
    ;;
    'CPL' )
      ICEIFLAG='T'
      if [ ${waveesmfGRD} ]
      then
        ICEFLAG="CPL:${waveesmfGRD}"
        CPLILINE="  '${waveesmfGRD}' F F ${WNDIFLAG} T F F F F F"
      else 
        ICEFLAG="CPL:native"
      fi
    ;;
  esac

  case ${WW3CURINP} in
    'YES' ) 
      if [ "$WAVECUR_FID" != "$WAVEICE_FID" ]; then
        NFGRIDS=$(expr $NFGRIDS + 1)
        CURRLINE="  '$WAVECUR_FID'  F T F F F F F F F"
        CURRFLAG="$WAVECUR_FID"
      else # cur fields share the same grid as ice grid
        ICELINE="  '$WAVEICE_FID'  F T F ${ICEIFLAG} F F F F F"
        CURRFLAG="$WAVEICE_FID"
      fi
    ;;
    'CPL' )
      CURIFLAG='T'
      if [ ${waveesmfGRD} ]
      then
        CURRFLAG="CPL:${waveesmfGRD}"
        CPLILINE="  '${waveesmfGRD}' F T ${WNDIFLAG} ${ICEFLAG} F F F F F"
      else 
        CURRFLAG="CPL:native"
      fi
    ;;
  esac

  unset agrid
  agrid=
  gline=
  GRDN=0
#  grdGRP=1 # Single group for now
  for grid in ${waveGRD} 
  do
    GRDN=$(expr ${GRDN} + 1)
    agrid=( ${agrid[*]} ${grid} )
    NMGRIDS=$(expr $NMGRIDS + 1)
    gridN=$(echo $waveGRDN | awk -v i=$GRDN '{print $i}')
    gridG=$(echo $waveGRDG | awk -v i=$GRDN '{print $i}')
    gline="${gline}'${grid}'  'no' 'CURRFLAG' 'WINDFLAG' 'ICEFLAG'  'no' 'no' 'no' 'no' 'no'  ${gridN} ${gridG}  0.00 1.00  F\n"
  done
  gline="${gline}\$"
  echo $gline

  sed -e "s/NFGRIDS/$NFGRIDS/g" \
      -e "s/NMGRIDS/${NMGRIDS}/g" \
      -e "s/FUNIPNT/${FUNIPNT}/g" \
      -e "s/IOSRV/${IOSRV}/g" \
      -e "s/FPNTPROC/${FPNTPROC}/g" \
      -e "s/FGRDPROC/${FGRDPROC}/g" \
      -e "s/OUTPARS/${OUTPARS_WAV}/g" \
      -e "s/CPLILINE/${CPLILINE}/g" \
      -e "s/UNIPOINTS/${UNIPOINTS}/g" \
      -e "s/GRIDLINE/${gline}/g" \
      -e "s/ICELINE/$ICELINE/g" \
      -e "s/CURRLINE/$CURRLINE/g" \
      -e "s/WINDLINE/$WINDLINE/g" \
      -e "s/ICEFLAG/$ICEFLAG/g" \
      -e "s/CURRFLAG/$CURRFLAG/g" \
      -e "s/WINDFLAG/$WINDFLAG/g" \
      -e "s/RUN_BEG/$time_beg/g" \
      -e "s/RUN_END/$time_end/g" \
      -e "s/OUT_BEG/$time_beg_out/g" \
      -e "s/OUT_END/$time_end/g" \
      -e "s/DTFLD/ $DTFLD_WAV/g" \
      -e "s/FLAGMASKCOMP/ $FLAGMASKCOMP/g" \
      -e "s/FLAGMASKOUT/ $FLAGMASKOUT/g" \
      -e "s/GOFILETYPE/ $GOFILETYPE/g" \
      -e "s/POFILETYPE/ $POFILETYPE/g" \
      -e "s/FIELDS/$FIELDS/g" \
      -e "s/DTPNT/ $DTPNT_WAV/g" \
      -e "/BUOY_FILE/r buoy.loc" \
      -e "s/BUOY_FILE/DUMMY/g" \
      -e "s/RST_BEG/$time_rst_ini/g" \
      -e "s/RSTTYPE/$RSTTYPE_WAV/g" \
      -e "s/RST_2_BEG/$time_rst2_ini/g" \
      -e "s/DTRST/$DT_1_RST_WAV/g" \
      -e "s/DT_2_RST/$DT_2_RST_WAV/g" \
      -e "s/RST_END/$time_rst1_end/g" \
      -e "s/RST_2_END/$time_rst2_end/g" \
                                     ww3_multi.inp.tmpl | \
  sed -n "/DUMMY/!p"               > ww3_multi.inp

  rm -f ww3_multi.inp.tmpl buoy.loc

  if [ -f ww3_multi.inp ]
  then
    echo " Copying file ww3_multi.${WAV_MOD_TAG}.inp to $COMOUT "
    cp ww3_multi.inp ${COMOUT}/rundata/ww3_multi.${WAV_MOD_TAG}.${cycle}.inp
  else
    echo "FATAL ERROR: file ww3_multi.${WAV_MOD_TAG}.${cycle}.inp NOT CREATED, ABORTING"
    err=13;export err;${errchk}
  fi 

# 6. Copy rmp grid remapping pre-processed coefficients

  if [ "${USE_WAV_RMP:-YES}" = "YES" ]; then
    if ls $FIXwave/rmp_src_to_dst_conserv_* 2> /dev/null
    then
      for file in $(ls $FIXwave/rmp_src_to_dst_conserv_*) ; do
        cp -f $file ${COMOUT}/rundata
      done
    else
      set +x
      echo ' '
      echo '************************************************ '
      echo '*** FATAL ERROR : NO PRECOMPUTED RMP FILES FOUND *** '
      echo '************************************************ '
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      err=13;export err;${errchk}
    fi
  fi


# --------------------------------------------------------------------------- #
# 6.  Output to /com

  if [ "$SENDCOM" = 'YES' ]
  then

   if [ "${WW3ATMINP}" = 'YES' ]; then

    for grdID in $WAVEWND_FID $curvID 
    do
      set +x
      echo ' '
      echo "   Saving wind.$grdID as $COMOUT/rundata/${WAV_MOD_TAG}.$grdID.$PDY$cyc.wind"
      echo "   Saving times.$grdID file as $COMOUT/rundata/${WAV_MOD_TAG}.$grdID.$PDY$cyc.$grdID.wind.times"
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      cp wind.$grdID $COMOUT/rundata/${WAV_MOD_TAG}.$grdID.$PDY$cyc.wind
      cp times.$grdID $COMOUT/rundata/${WAV_MOD_TAG}.$grdID.$PDY$cyc.$grdID.wind.times
    done
   fi

#   if [ "${WW3CURINP}" = 'YES' ]; then
#
#    for grdID in $WAVECUR_FID
#    do
#      set +x
#      echo ' '
#      echo "   Saving cur.$grdID as $COMOUT/rundata/${WAV_MOD_TAG}.$grdID.$PDY$cyc.cur"
#      echo ' '
#      [[ "$LOUD" = YES ]] && set -x
#      cp cur.$grdID $COMOUT/rundata/${WAV_MOD_TAG}.$grdID.$PDY$cyc.cur
#    done
#   fi
  fi 

  rm -f wind.*
  rm -f $WAVEICE_FID.*
  rm -f times.*

# --------------------------------------------------------------------------- #
# 7.  Ending output

  set +x
  echo ' '
  echo "Ending at : $(date)"
  echo ' '
  echo '                     *** End of MWW3 preprocessor ***'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  exit $err

# End of MWW3 preprocessor script ------------------------------------------- #
