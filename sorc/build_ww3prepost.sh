#!/bin/sh
set -x

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

finalexecdir=$( pwd -P )/../exec

set +x
source ./machine-setup.sh > /dev/null 2>&1

source ../modulefiles/modulefile.ww3.$target
set -x

if [ $target = hera ]; then target=hera.intel ; fi
if [ $target = orion ]; then target=orion.intel ; fi
if [ $target = stampede ]; then target=stampede.intel ; fi

cd WW3.fd
export WW3_DIR=$( pwd -P )/model
export WW3_BINDIR="${WW3_DIR}/bin"
export WW3_TMPDIR=${WW3_DIR}/tmp
export WW3_EXEDIR=${WW3_DIR}/exe
export WW3_COMP=$target 
export SWITCHFILE="${WW3_DIR}/esmf/switch"

export WWATCH3_ENV=${WW3_BINDIR}/wwatch3.env
export PNG_LIB=${PNG_LIB:-$PNG_ROOT/lib64/libpng.a}
export Z_LIB=${Z_LIB:-$ZLIB_ROOT/lib/libz.a}
export JASPER_LIB=${JASPER_LIB:-$JASPER_ROOT/lib64/libjasper.a}
export NETCDF_CONFIG=$NETCDF_ROOT/bin/nc-config

if [ -f $WWATCH3_ENV]; then rm $WWATCH3_ENV ; fi 

echo '#'                                              > $WWATCH3_ENV
echo '# ---------------------------------------'      >> $WWATCH3_ENV
echo '# Environment variables for wavewatch III'      >> $WWATCH3_ENV
echo '# ---------------------------------------'      >> $WWATCH3_ENV
echo '#'                                              >> $WWATCH3_ENV
echo "WWATCH3_DIR      $WW3_DIR"                      >> $WWATCH3_ENV
echo "WWATCH3_TMP      $WW3_TMPDIR"                   >> $WWATCH3_ENV
echo 'WWATCH3_SOURCE   yes'                           >> $WWATCH3_ENV
echo 'WWATCH3_LIST     yes'                           >> $WWATCH3_ENV
echo ''                                               >> $WWATCH3_ENV

${WW3_BINDIR}/w3_clean -m 
${WW3_BINDIR}/w3_setup -q -c $WW3_COMP $WW3_DIR

echo $(cat ${SWITCHFILE}) > ${WW3_BINDIR}/tempswitch

sed -e "s/DIST/SHRD/g"\
    -e "s/OMPG/ /g"\
    -e "s/OMPH/ /g"\
    -e "s/MPIT/ /g"\
    -e "s/MPI/ /g"\
    -e "s/PDLIB/ /g"\
       ${WW3_BINDIR}/tempswitch > ${WW3_BINDIR}/switch

# Build exes for prep jobs and post jobs (except grib):
prep_exes="ww3_grid ww3_prep ww3_prnc ww3_grid"
post_exes="ww3_outp ww3_outf ww3_outp ww3_gint ww3_ounf ww3_ounp"
for prog in $prep_exes $post_exes; do
    ${WW3_BINDIR}/w3_make ${prog}
    rc=$?
    if [[ $rc -ne 0 ]] ; then
        echo "FATAL: Error building ${prog} (Error code ${rc})"
        exit $rc
    fi
done

# Update switch for grib: 
echo $(cat ${SWITCHFILE}) > ${WW3_BINDIR}/tempswitch

sed -e "s/DIST/SHRD/g"\
    -e "s/OMPG/ /g"\
    -e "s/OMPH/ /g"\
    -e "s/MPIT/ /g"\
    -e "s/MPI/ /g"\
    -e "s/PDLIB/ /g"\
    -e "s/NOGRB/NCEP2 NCO/g"\
       ${WW3_BINDIR}/tempswitch > ${WW3_BINDIR}/switch

# Build exe for grib
${WW3_BINDIR}/w3_make ww3_grib
rc=$?
if [[ $rc -ne 0 ]] ; then
    echo "FATAL: Unable to build ww3_grib (Error code $rc)"
    exit $rc
fi

# Update switch for multi: 
echo $(cat ${SWITCHFILE}) > ${WW3_BINDIR}/tempswitch

sed -e "s/MPIT/ /g"\
    -e "s/PDLIB/ /g"\
       ${WW3_BINDIR}/tempswitch > ${WW3_BINDIR}/switch

# Build exe for multi
${WW3_BINDIR}/w3_make ww3_multi
rc=$?
if [[ $rc -ne 0 ]] ; then
    echo "FATAL: Unable to build ww3_multi (Error code $rc)"
    exit $rc
fi

# Copy to top-level exe directory
for prog in $prep_exes $post_exes ww3_grib ww3_multi; do
    cp $WW3_EXEDIR/$prog $finalexecdir/
    rc=$?
    if [[ $rc -ne 0 ]] ; then
        echo "FATAL: Unable to copy $WW3_EXEDIR/$prog to $finalexecdir (Error code $rc)"
        exit $rc
    fi
done

${WW3_BINDIR}/w3_clean -c
rm ${WW3_BINDIR}/tempswitch

exit 0
