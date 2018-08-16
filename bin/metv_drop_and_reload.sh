#!/bin/sh

# Drop and recreate the database
/d1/pmemet/projects/saudi/rtf3h/pmemet/user/bin/metv_drop_and_create.sh

# Generate list of dates to load
date_list=`ls -1d /d2/pmemet/met_out/*/* | cut -d'/' -f6 | sort -u | egrep "20130[3-9]|20131"`
n_dates=`echo $date_list | wc -w`

# Load MET output for each date
n=0
for cur_date in $date_list; do

  n=`expr $n + 1`

  short_date=`echo $cur_date | cut -c1-8`
  log_dir="/d2/pmemet/log/metv_load_valid/${short_date}"
  log_file="${log_dir}/metv_load_valid_${cur_date}.log"

  mkdir -p $log_dir

  echo "[`date +%Y%m%d_%H%M%S`] Loading date $n of $n_dates: /d1/pmemet/projects/saudi/rtf3h/pmemet/user/bin/metv_load_valid.pl $cur_date pme_da_d02 pme_da_d03 pme_noda_c2d02_d02 pme_noda_c2d03_d02 pme_wrf22_c2d01_d02 gfs_d02 gfs_d03 >& $log_file"
  /d1/pmemet/projects/saudi/rtf3h/pmemet/user/bin/metv_load_valid.pl $cur_date pme_da_d02 pme_da_d03 pme_noda_c2d02_d02 pme_noda_c2d03_d02 pme_wrf22_c2d01 gfs_d02 gfs_d03 >& $log_file

done
