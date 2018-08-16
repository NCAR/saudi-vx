#!/usr/bin/perl

################################################################################
#
# Script Name: patch_little_r_prmsl_qc.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 12/09/2013
#
# Description:
#   This script must be passed two arguments, an input little R file name
#   and an output file name.  This script will copy the input file to the
#   output only modifying the quality control flag for PRMSL observations.
#   The input PRMSL QC flag was set by the NCEP data assimilation system and not
#   modified by the RTFDDA system.  NCEP QC values <= 2 are converted to an
#   RTFDDA QC value of 10, while those > 2 are converted to 0.
#
# Dependencies:
#   None
#
# Arguments:
#   Input little_r file to be reformatted.
#   Output file name.
#
################################################################################

use lib "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/lib";

use strict;
use warnings;

use POSIX;
use File::Basename;
use VxUtil;

################################################################################

# Constants
my $lr_hdr_len = 600;
my $lr_missing_value = -888888;

################################################################################

# Check the number of arguments                                                                                                                                              
unless ( scalar @ARGV == 2 ) {
   die "\nERROR: Must have exactly 2 arguments: input and output file names\n\n";
}

# Print begin time
print "\n", $0, " - started at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";

my $in_file_name  = $ARGV[0];
my $out_file_name = $ARGV[1];
my $patches = 0;

# Read the input file line by line
print("Reading: $in_file_name\n");
open (IN_FILE,  "<", $in_file_name ) or die "\nERROR: Could not open input file for reading: $in_file_name\n\n";
open (OUT_FILE, ">", $out_file_name) or die "\nERROR: Could not open output file for writing: $out_file_name\n\n";
while (<IN_FILE>) {
  chomp;

  # Check for little_r header line based on it's length
  if( length $_ >= $lr_hdr_len ) {

    # Parse MSLP value and QC flag
    # MSLP Value: columns 340-352
    # MSLP QC:    columns 353-359
    my $prmsl_ob = substr $_, 340, 13;
    my $prmsl_qc = substr $_, 353, 7;
    if ( $prmsl_ob != $lr_missing_value && $prmsl_qc != $lr_missing_value ) {
      my $new_qc = sprintf "%7i", ( $prmsl_qc <= 2 ? 10 : 0 );
      print "Line $.: Switching QC Flag \"$prmsl_qc\" to \"$new_qc\" for PRMSL value $prmsl_ob\n";
      substr $_, 353, 7, $new_qc;
      $patches++;
    }
  }

  print OUT_FILE "$_\n";
}
close(IN_FILE);
close(OUT_FILE);
print("Patched $patches PRMSL QC flags values.\n");
print("Writing: $out_file_name\n");

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";

