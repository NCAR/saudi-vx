#!/bin/sh

for domain in `echo "d02 d03"`; do

  /d1/johnhg/MET/MET_development/svn-met-dev.cgd.ucar.edu/trunk/met/bin/gen_circle_mask \
  pme_da_${domain}_domain.grb \
  saudi_radar_list_${domain}.txt \
  ${domain}_Radar_mask.nc

  export domain="${domain}"

  /d1/johnhg/MET/MET_development/svn-met-dev.cgd.ucar.edu/trunk/met/bin/plot_data_plane \
  ${domain}_Radar_mask.nc \
  ${domain}_Radar_mask.ps \
  'name="${domain}_Radar"; level="(*,*)";'

  convert -rotate 90 -background white -flatten ${domain}_Radar_mask.ps ${domain}_Radar_mask.png

done
