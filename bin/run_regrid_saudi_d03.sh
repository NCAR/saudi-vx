#!/bin/sh

for file in `ls /d2/pmemet/fcst/pme_noda_native/*d03*grb1*`; do

/d1/pmemet/projects/saudi/rtf3h/pmemet/user/bin/regrid_saudi.pl \
  -out_dir /d2/pmemet/fcst/pme_noda \
  -out_prefix pme_noda_c2d03 \
  -out_domain d02 \
  $file

done
