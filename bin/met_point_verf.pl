#!/usr/bin/perl

################################################################################
#
# Script Name: met_point_verf.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 10/16/2012
#
# Description:
#
# Dependencies:
#   The VXUTIL_CONST environment variable must be set to the file containing
#   project constants.
#
# Arguments:
#   - Model to be verified.
#   - Valid time in YYYMMDDHH format.
#   - Verification domain.
#
# Example:
#   met_point_verf.pl \
#     pme_da 2012101523 d02
#
################################################################################

use lib "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/lib";

use strict;
use warnings;

use POSIX;
use File::Basename;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use VxUtil;

################################################################################

# Print begin time
print "\n", $0, " - started at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";

# Check the number of arguments
unless ( scalar @ARGV == 3 ) {
  die "\nERROR: Must have exactly 3 arguments: " .
      "model name, valid time, domain.\n\n";
}

# Store the arguments
( my $model, my $valid, my $domain ) = @ARGV;

print "Model:  $model\n" .
      "Valid:  $valid\n" .
      "Domain: $domain\n\n";

# Set environment variables to be used in MET configuration files
$ENV{model}      = $model;
$ENV{domain}     = $domain;
$ENV{vx_mask}    = vx_const_get("PS_" . uc($domain) . "_VX_MASK");
$ENV{config_dir} = vx_const_get("CONFIG_DIR");

# Get the observation file
my %tmpl = ( valid => $valid );
my $obs_file = vx_file_tmpl_gen(vx_const_get("POINT_OBS_TMPL"), \%tmpl);

# Check that the observation file exists
unless ( -e $obs_file ) {
  die "\nERROR: Observation file does not exist: $obs_file\n\n";
}

# Get the initialization frequency and lead times for this model/domain
my $init_freq = vx_const_get(uc($model) . "_INIT_FREQ");
my $lead_max  = max ( vx_util_seq(vx_const_get(uc($model) . "_" . uc($domain) . "_LEAD_SEQ")) );

# Compute the most recent model initialization time
my $valid_ut  = vx_date_parse_date ( $valid );
my $valid_ymd = strftime ( "%Y%m%d", localtime ( $valid_ut ) ); 
my $valid_hr  = strftime ( "%H", localtime ( $valid_ut ) );
my $init_ut   = int( $valid_ut/$init_freq ) * $init_freq;
my $lead_sec  = $valid_ut - $init_ut; 

# Make the output directory
my $out_dir = vx_const_get("OUT_DIR") . "/${model}_${domain}/${valid_ymd}/${valid}/point_stat";
vx_run_cmd ( "mkdir -p $out_dir" );

# Loop over the initialization and lead times for this valid time
while ( $lead_sec < $lead_max * 3600 ) {

  my $init = strftime ( "%Y%m%d%H", localtime ( $init_ut ) );
  print "\nVerifying the " . $lead_sec/3600 . " hr lead of the $init initialization.\n\n";

  # Set up the file template
  $tmpl{init}   = $init;
  $tmpl{domain} = $domain;

  # Get the forecast file
  my $fcst_file = vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_TMPL"),  \%tmpl);

  # Check file existence
  if ( ! -e $fcst_file ) {
    print "WARNING: Expected forecast file does not exist: $fcst_file\n";
  }
  else {

    # Run Point-Stat for ADPSFC observations
    vx_run_cmd ( vx_const_get("MET_EXEC") . "/point_stat $fcst_file $obs_file " .
                 vx_const_get("CONFIG_DIR") . "/PointStatConfig_ADPSFC " .
                 "-outdir $out_dir -v 2" );

    # Run Point-Stat for ADPSFC observations over individual stations
    vx_run_cmd ( vx_const_get("MET_EXEC") . "/point_stat $fcst_file $obs_file " .
                 vx_const_get("CONFIG_DIR") . "/PointStatConfig_ADPSFC_SID " .
                 "-outdir $out_dir -v 2" );

    # Run Point-Stat for ADPUPA observations at 00Z and 12Z
    if ( $valid_hr == "00" || $valid_hr == "12" ) {
      vx_run_cmd ( vx_const_get("MET_EXEC") . "/point_stat $fcst_file $obs_file " .
                   vx_const_get("CONFIG_DIR") . "/PointStatConfig_ADPUPA " .
                   "-outdir $out_dir -v 2" );
    }
  }

  # Decrement the init time and increment the lead time
  $init_ut  -= $init_freq;
  $lead_sec += $init_freq; 

}

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";
