#! /bin/bash

if [[ -e DCMS/new_dcms ]] ; then
    rm -rf DCMS/new_dcms
fi
p.pl --prjroot=DCMS/DCMS_DEMO/project_space --outdir=DCMS/new_dcms --mapfile=DCMS/DCMS_DEMO/mapfile.txt
