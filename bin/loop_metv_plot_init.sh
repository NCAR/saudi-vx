#!/bin/sh

bin_dir=/d1/pmemet/projects/saudi/rtf3h/pmemet/user/bin

# Begin time, end time, and increment
beg="20130322 00" 
end="20131010 12"
inc=21600

beg_ut=`date -ud "${beg}" +%s`
end_ut=`date -ud "${end}" +%s`

ut=${beg_ut}
while [ ${ut} -le ${end_ut} ]
do
  cur=`date -ud '1970-01-01 UTC '${ut}' seconds' +%Y%m%d%H`
  echo "`date`: ${bin_dir}/run_metv_plot_init.sh ${cur}"
  ${bin_dir}/run_metv_plot_init.sh ${cur}
  ut=`expr ${ut} + ${inc}`
done


