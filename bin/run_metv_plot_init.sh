#!/bin/sh

bin_dir=/d1/pmemet/projects/saudi/rtf3h/pmemet/user/bin
log_dir=/d2/pmemet/log/metv_plot_init

# Use time from the command line
if [ $# -gt 0 ]; then
  # Use the YYYYMMDDHH argument provided on the command line
  ymd=` echo $1 | cut -c1-8`
  ymdh=`echo $1 | cut -c1-10`
else
  # Otherwise, run the script for 12-hours prior to the current time
  cur_ut=`date +%s`
  prv_ut=`expr ${cur_ut} - 43200`
  ymd=`   date -ud '1970-01-01 UTC '${prv_ut}' seconds' +%Y%m%d`
  ymdh=`  date -ud '1970-01-01 UTC '${prv_ut}' seconds' +%Y%m%d%H`
fi

# Create a log directory if necessary
mkdir -p ${log_dir}/${ymd}

${bin_dir}/metv_plot_init.pl ${ymdh} >& ${log_dir}/${ymd}/run_metv_plot_init_${ymdh}.log

