#!/usr/bin/perl

################################################################################
#
# Script Name: regrid_saudi.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 10/10/2012
#
# Description:
#   For each input file name passed to this script on the command line, it
#   converts the file from GRIB2 to GRIB1, if necessary, and regrids it to the
#   domains used by the saudi project.  The output is written to this directory:
#   OUTPUT_DIR/YYYYMMDDHH
#
# Dependencies:
#   The VXUTIL_CONST environment variable must be set to the file containing
#   project constants.
#   Calls copygb_budget.pl script.
#
# Arguments:
#   Input GRIB or GRIB2 files to be regridded.
#   -out_dir path to specify the output location.
#   -out_prefix string to specify a prefix for the output files.
#   -out_domain string to specify output domains to be used.
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
my $out_prefix = "";
my @in_files;
my $tmp_file;
my @domains;

# Parse command line options
while ( my $arg = shift ) {
  if    ( $arg eq "-out_dir"    ) { $out_dir    = shift;  }
  elsif ( $arg eq "-out_prefix" ) { $out_prefix = shift;  }
  elsif ( $arg eq "-out_domain" ) { push @domains, shift; }
  else                            { push @in_files, $arg; }
}

# If -out_domain not used, retrieve domains from the constants file
if ( scalar(@domains) == 0 ) {
  @domains = vx_const_get("DOMAINS");
}

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

  # Check for GRIB2 format
  if ( lc($in_file) =~ m/grib2/ || lc($in_file) =~ m/grb2/ ) {

    # Convert from GRIB2 to GRIB1
    my $tmp_file_name = $in_file_name;
    $tmp_file_name =~ s/grib2/grib/;
    $tmp_file_name =~ s/grb2/grb/;
    $tmp_file = vx_const_get("TMP_DIR") . "/" . $tmp_file_name;
    vx_run_cmd ( vx_const_get("CNVGRIB_EXEC") . " -g21 $in_file $tmp_file" );
    $in_file = $tmp_file;
  }

  # Get the date from the GRIB file
  my $WGRIB_EXEC = vx_const_get("WGRIB_EXEC");
  my $init_ymdh = qx/$WGRIB_EXEC -V -d 1 $in_file | grep date | awk '{print \$3}'/;
  my $fcst_hr = qx/$WGRIB_EXEC -d 1 $in_file | awk 'BEGIN {FS=":"}; {print \$13};' | sed 's\/hr fcst\/\/g'/;
  chomp $init_ymdh;
  chomp $fcst_hr;
  if ( $fcst_hr eq "anl" ) {
    $fcst_hr = "0";
  }
  my $valid_ymdh = vx_date_calc_valid ( $init_ymdh, $fcst_hr );

  # Process each output domain
  for my $domain ( @domains ) {

    # Retrieve the grid specification for the current domain
    my $gridspec = vx_const_get(uc($domain) . "_GRIDSPEC");

    # Construct the output directory
    my $out_file_path = "$out_dir/$init_ymdh";
    vx_run_cmd ( "mkdir -p $out_file_path" );

    # Run the copygb command
    my $out_file = "$out_file_path/${out_prefix}_${domain}_${valid_ymdh}00.grb";   
    vx_run_cmd ( vx_const_get("BIN_DIR") . "/copygb_budget.pl -xg\"'$gridspec'\" $in_file $out_file" );
  }
} # end foreach

# Remove the temp file
if ( defined $tmp_file ) {
  vx_run_cmd ( "rm -f $tmp_file" );
}
  
# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";
