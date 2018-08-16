#!/usr/bin/perl

################################################################################
#
# Script Name: copygb_budget.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 10/16/2012
#
# Description:
#   Call copygb using the arguments provided.  However, split the call up into
#   two calls, one using budget interpolation and a second using the default
#   interpolation.
#
# Dependencies:
#   The VXUTIL_CONST environment variable must be set to the file containing
#   project constants.
#
# Arguments:
#   Arguments for copygb
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

# Arguments
my $in_file;
my $out_file;
my @copygb_args;

# Parse command line options
while ( my $arg = shift ) {
  if ( index ( $arg, "-" ) == 0 ) { push @copygb_args, $arg; }
  elsif ( !defined ( $in_file ) ) { $in_file = $arg;         }
  else                            { $out_file = $arg;        }
}

# Check for input/output files
if ( !defined ( $in_file ) || !defined ( $out_file ) ) {
   die "ERROR: Must specify input and output filenames.\n";
}

# Process file names
my $TMP_DIR = vx_const_get("TMP_DIR");
my ($in_file_name, $in_file_path) = fileparse($in_file);
my $wgrib_budget   = $TMP_DIR . "/" . $in_file_name . "_WGRIB_BUDGET";
my $wgrib_default  = $TMP_DIR . "/" . $in_file_name . "_WGRIB_DEFUALT";
my $copygb_budget  = $TMP_DIR . "/" . $in_file_name . "_COPYGB_BUDGET";
my $copygb_default = $TMP_DIR . "/" . $in_file_name . "_COPYGB_DEFUALT";

# Run wgrib to subset the input file
my $WGRIB_EXEC = vx_const_get("WGRIB_EXEC");
vx_run_cmd ( "$WGRIB_EXEC $in_file | egrep    \"" . vx_const_get("COPYGB_BUDGET_VARS") .
             "\" | $WGRIB_EXEC $in_file -i -grib -o $wgrib_budget  > /dev/null" );
vx_run_cmd ( "$WGRIB_EXEC $in_file | egrep -v \"" . vx_const_get("COPYGB_EXCLUDE_VARS") .
             "\" | $WGRIB_EXEC $in_file -i -grib -o $wgrib_default > /dev/null" );

# Run copygb on the subsetted files
my $COPYGB_EXEC = vx_const_get("COPYGB_EXEC");
vx_run_cmd ( "$COPYGB_EXEC @copygb_args -i3 $wgrib_budget  $copygb_budget  > /dev/null" );
vx_run_cmd ( "$COPYGB_EXEC @copygb_args     $wgrib_default $copygb_default > /dev/null" );

# Concatenate the two output files
vx_run_cmd ( "cat $copygb_budget $copygb_default > $out_file" );

# Remove the temporary files
foreach my $tmp_file ( ($wgrib_budget, $wgrib_default, $copygb_budget, $copygb_default) ) {
  vx_run_cmd ( "rm -f $tmp_file" );
}

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";
