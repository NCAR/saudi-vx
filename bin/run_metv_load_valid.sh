#!/bin/sh

bin_dir=/d1/pmemet/projects/saudi/rtf3h/pmemet/user/bin
log_dir=/d2/pmemet/log/metv_load_valid
model_list="pme_da_d02 pme_da_d03 pme_noda_c2d02_d02 pme_noda_c2d03_d02 pme_wrf22_c2d01_d02 gfs_d02 gfs_d03"

beg_ut=`date -ud ''2014-05-20' UTC '07:00:00'' +%s`
end_ut=`date -ud ''2014-06-03' UTC '23:00:00'' +%s`

cur_ut=$beg_ut

while [ $cur_ut -le $end_ut ]; do

  # Convert to YYYYMMDDHH format
  cur_ymd=` date -ud '1970-01-01 UTC '$cur_ut' seconds' +%Y%m%d`
  cur_ymdh=`date -ud '1970-01-01 UTC '$cur_ut' seconds' +%Y%m%d%H`
  
  echo "CALLING: ${bin_dir}/metv_load_valid.pl ${cur_ymdh} ${model_list} >& ${log_dir}/${cur_ymd}/metv_load_valid_${cur_ymdh}.log"
  ${bin_dir}/metv_load_valid.pl ${cur_ymdh} ${model_list} >& ${log_dir}/${cur_ymd}/metv_load_valid_${cur_ymdh}.log
  
  # Increment one hour
  cur_ut=`expr $cur_ut + 3600`

done
