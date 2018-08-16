#!/usr/bin/perl

################################################################################
#
# Script Name: rfmt_obs_little_r.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 10/16/2012
#
# Description:
#   For each input file name passed to this script on the command line, it
#   converts the file to NetCDF using the MET ASCII2NC utility.
#   The output is written to the OUTPUT_DIR directory.
#
# Dependencies:
#   The VXUTIL_CONST environment variable must be set to the file containing
#   project constants.
#
# Arguments:
#   Input little_r files to be reformatted.
#   -out_dir path to specify the output location.
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

my $out_dir = ".";
my @in_files;

# Parse command line options
while ( my $arg = shift ) {
  if ( $arg eq "-out_dir" ) { $out_dir    = shift;  }
  else                      { push @in_files, $arg; }
}

# Make the output directory
vx_run_cmd ( "mkdir -p $out_dir" );

print "Processing ", scalar @in_files, " input file(s).\n";

# Process each input file
foreach my $in_file ( @in_files ) {

  # Check that the file exists
  unless ( -e $in_file ) {
    die "ERROR: Input file does not exist: $in_file\n";
  }

  # List the input file
  print "\nProcessing input file: $in_file\n";
  my ($in_file_name, $in_file_path) = fileparse($in_file);

  # Create temporary input file with modified QC flag values for PRMSL
  my $tmp_file = "$out_dir/${in_file_name}_PRMSL_QC";
  vx_run_cmd ( vx_const_get("BIN_DIR") . "/patch_little_r_prmsl_qc.pl $in_file $tmp_file" );

  # Run ASCII2NC
  my $out_file = "$out_dir/${in_file_name}.nc";
  vx_run_cmd ( vx_const_get("MET_EXEC") . "/ascii2nc $tmp_file $out_file" );

  # Check that the output file exists
  unless ( -e $out_file ) {
    die "ERROR: Expected output NetCDF file does not exist: $out_file\n";
  }

  # Remove the temp file
  vx_run_cmd ( "rm -f $tmp_file" );

} # end foreach

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";
