#!/usr/bin/perl
use strict;
use warnings;

################################################################################
#
# Script Name: gen_saudi_poly_mask.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 11/09/2012
#
# Description:
#    This script prepares verification masking regions masks for use by the MET
#    verification package for the 2012/2013 GWPME model runs on the saudi-c3
#    machine.  The following masks are generated:
#    - Full grid for the d02/d03 domains
#    - Saudi Provinces for the d02/d03 domains
#    - d03 subset of the d02 domain
#
#    This script parses the lat/lon data file describing the Saudi Province
#    boundaries.  For each province, it reformats the bounding lat/lon's and
#    runs the gen_poly_mask tool to create masks for the d02 and d03 domains.
#    It then runs an Rscript to combine the individual masks into a single one
#    for each domain.  It then runs the plot_data_plane tool to plot the
#    mask file for each domain.   Lastly, it converts the postscript plot to
#    png format.
#
# Dependencies:
#    Paths to the MET build and location of input data files must be set
#    correctly at the top of the script.
#
# Arguments:
#   None.
#
# Example:
#   gen_saudi_poly_mask.pl
#
################################################################################

# Constants
my $met_base        = "/d1/pmemet/MET/MET_releases/METv4.1_beta4";
my $gen_poly_mask   = "$met_base/bin/gen_poly_mask";
my $plot_data_plane = "$met_base/bin/plot_data_plane";
my $data_file       = "in/Saudi_provinces.txt";
my $d02_file        = "in/d02_sample.grib";
my $d03_file        = "in/d03_sample.grib";
my $poly_file       = "in/mask.poly";
my $out_dir         = "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/config/mask";

# Map Saudi Arabian province names to vx_mask names
my %mask_names;
$mask_names{"Al Bahah"}                = "Bahah";
$mask_names{"Al Hudud ash Shamaliyah"} = "Hudud";
$mask_names{"Al Jawf"}                 = "Jawf";
$mask_names{"Al Madinah"}              = "Madinah";
$mask_names{"Al Qasim"}                = "Qasim";
$mask_names{"Al Qurayyat"}             = "Qurayyat";
$mask_names{"Ar Riyad"}                = "Riyad";
$mask_names{"Ash Sharqiyah"}           = "Sharqiyah";
$mask_names{"'Asir"}                   = "Asir";
$mask_names{"Ha'il"}                   = "Hail";
$mask_names{"Jizan"}                   = "Jizan";
$mask_names{"Makkah"}                  = "Makkah";
$mask_names{"Najran"}                  = "Najran";
$mask_names{"Tabuk"}                   = "Tabuk";

# Create full d02/d03 masks
print "Generating full d02 mask...\n";
print qx($gen_poly_mask $d02_file $d02_file $out_dir/d02_Full_mask.nc -name d02_Full);
print "Generating full d03 mask...\n";
print qx($gen_poly_mask $d03_file $d03_file $out_dir/d03_Full_mask.nc -name d03_Full);

# Create the d03 subset mask for d02
print "Generating d03 subset mask for d02...\n";
print qx($gen_poly_mask $d02_file $d03_file $out_dir/d02_Sub_d03_mask.nc -name d02_Sub_d03);

# Loop through the provinces
foreach my $name ( keys %mask_names ) {

  print "Working on province \"$name\"...\n";
  print "CALLING: qx(grep \"$name\" $data_file)\n";
  my @mask_data = qx(grep "$name" $data_file);

  # Create polyline output file
  open(POLY_FILE, ">$poly_file");
  print POLY_FILE "$mask_names{$name}\n";

  # Loop through the lat/lon point
  foreach my $line ( @mask_data ) {
     chomp $line;
     $line =~ s/\r\n/\n/g;
     my @tokens = split(',', $line);
     print POLY_FILE $tokens[5] . " " . $tokens[4]. "\n";
  }

  # Call MET gen_poly_mask tool
  print "Generating d02 mask...\n";
  print qx($gen_poly_mask $d02_file $poly_file $out_dir/d02_$mask_names{$name}_prov_mask.nc -name d02_$mask_names{$name});
  print "Generating d03 mask...\n";
  print qx($gen_poly_mask $d03_file $poly_file $out_dir/d03_$mask_names{$name}_prov_mask.nc -name d03_$mask_names{$name});

  close(POLY_FILE);
}

foreach my $domain (("d02", "d03")) {

  # Merge the mask files together
  print "Merging the $domain masks...\n";
  print qx(Rscript merge_nc_mask.R $out_dir/$domain*_prov_mask.nc -out $out_dir/${domain}_Saudi_mask.nc -name ${domain}_Saudi);

  # Plot the masks
  print "Plotting the $domain masks...\n";
  print qx($plot_data_plane $out_dir/${domain}_Saudi_mask.nc $out_dir/${domain}_Saudi_mask.ps 'name="${domain}_Saudi"; level="(\*,\*)";');
  print qx(convert -rotate 90 $out_dir/${domain}_Saudi_mask.ps $out_dir/${domain}_Saudi_mask.png);
}
