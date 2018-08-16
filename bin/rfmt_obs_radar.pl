#!/usr/bin/perl

################################################################################
#
# Script Name: rfmt_obs_radar.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 10/16/2012
#
# Description:
#   For each input file name passed to this script on the command line, it
#   converts the file to GRIB1 using the Mdv2Grib utility.
#   The output is written to this directory:
#   OUTPUT_DIR/DOMAIN/YYYYMMDDHH
#   Where OUTPUT_DIR is set in the Mdv2Grib.params file.
#
# Dependencies:
#   The VXUTIL_CONST environment variable must be set to the file containing
#   project constants.
#   Calls copygb_budget.pl script.
#
# Arguments:
#   Input GRIB files to be regridded.
#
################################################################################

use lib "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/lib";

use strict;
use warnings;

use POSIX;
use File::Basename;
use VxUtil;

################################################################################

# Print begin time
print "\n", $0, " - started at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";

print "Processing ", scalar @ARGV, " input file(s).\n";

# Process each input file
foreach my $in_file ( @ARGV ) {

  # Check that the file exists
  unless ( -e $in_file ) {
    die "ERROR: Input file does not exist: $in_file\n";
  }

  # List the input file
  print "\nProcessing input file: $in_file\n";
  my @tokens = split '/', $in_file;
  my $in_file_name = pop @tokens;
  my $date_dir = pop @tokens;

  # Run Mdv2Grib
  vx_run_cmd ( vx_const_get("MDV2GRIB_EXEC") . " -f $in_file -params " .
               vx_const_get("CONFIG_DIR") . "/Mdv2Grib_APCP_01h.params >& /dev/null" );

  # Check that the output file exists
  my $grib_file = vx_const_get("RADAR_OBS_DIR") . 
                 "/native/${date_dir}/radar_APCP_01h_${date_dir}_" . 
                 substr ( $in_file_name, 0, 6 ) . ".grb";
  unless ( -e $grib_file ) {
    die "ERROR: Expected output GRIB file does not exist: $grib_file\n";
  }

  my ($grib_file_name, $grib_file_path) = fileparse($grib_file);

  # Process each output domain
  for my $domain ( vx_const_get("DOMAINS") ) {

    # Retrieve the grid specification for the current domain
    my $gridspec = vx_const_get(uc($domain) . "_GRIDSPEC");

    # Construct the output directory
    my $out_file_path = vx_const_get("RADAR_OBS_DIR") . "/${domain}/${date_dir}";
    vx_run_cmd ( "mkdir -p $out_file_path" );

    # Run the copygb command
    my $out_file = "$out_file_path/${grib_file_name}";
    vx_run_cmd ( vx_const_get("BIN_DIR") . "/copygb_budget.pl -xg\"'$gridspec'\" $grib_file $out_file" );
  }

} # end foreach

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";
