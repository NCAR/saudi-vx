#!/usr/bin/perl

################################################################################
#
# Script Name: met_grid_verf.pl
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
#   met_grid_verf.pl \
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
$ENV{model}    = $model;
$ENV{domain}   = $domain;
$ENV{grid_res} = vx_const_get(uc($domain) . "_GRIDRES");

# Get the accumulation intervals to be evaluated
my @accums = vx_const_get(uc($model) . "_VX_ACCUM");

# Convert valid time to unixtime
my $valid_ut  = vx_date_parse_date ( $valid );
my $valid_ymd = strftime ( "%Y%m%d", localtime ( $valid_ut ) );
my $valid_hr  = strftime ( "%H", localtime ( $valid_ut ) );

# Loop through the accumulations
my ($fcst_file, $obs_file);
my %tmpl = ( domain => $domain );
foreach my $accum( @accums ) {

  # Check if this accumulation should be evaluated for the current valid time
  if ( $valid_hr % $accum != 0 ) {
    print "\nSkipping the $accum hr accumulation for valid hour $valid_hr.\n";
    next;
  }

  print "\nVerifying the " . $accum . " hr accumulation.\n\n";

  # Get the observation file
  $tmpl{valid} = $valid;
  $tmpl{accum} = $accum;
  my $obs_file_grb = vx_file_tmpl_gen(vx_const_get("RADAR_OBS_GRB_TMPL"), \%tmpl);
  my $obs_file_nc  = vx_file_tmpl_gen(vx_const_get("RADAR_OBS_NC_TMPL"),  \%tmpl);

  # Observation file doesn't exist and must be computed
  unless ( -e $obs_file_grb or -e $obs_file_nc ) {

    # Set up a template for the previous day
    my %prev_tmpl = %tmpl;
    $prev_tmpl{valid} = strftime ( "%Y%m%d%H", localtime ( $valid_ut - 24 * 3600 ) );

    print "Creating observation file: $obs_file_nc\n";

    # Run PCP-Combine to sum up the hourly observations to the desired accumulation
    vx_run_cmd ( vx_const_get("MET_EXEC") . "/pcp_combine " .
                 "-sum 00000000_000000 01 $valid $accum $obs_file_nc " .
                 "-pcpdir " . vx_file_tmpl_gen(vx_const_get("RADAR_OBS_DIR_TMPL"), \%tmpl) . " " .
                 "-pcpdir " . vx_file_tmpl_gen(vx_const_get("RADAR_OBS_DIR_TMPL"), \%prev_tmpl) );
  }

  # Skip this accumulation interval if observation file still doesn't exist
  unless ( -e $obs_file_grb or -e $obs_file_nc ) {
    print "\nWARNING: Trouble creating observation file: $obs_file_nc\n\n";
    next;
  }

  # Store the observation file name
  my ($obs_name, $obs_level);
  if ( -e $obs_file_grb ) {
    $obs_file = $obs_file_grb;
    $obs_name  = "APCP";
    $obs_level = "A${accum}";
  }
  else {
    $obs_file = $obs_file_nc;
    $obs_name  = "APCP_${accum}";
    $obs_level = "(*,*)";
  }

  # Set environment variables to be used in MET configuration files
  $ENV{accum}     = $accum;
  $ENV{obs_name}  = $obs_name;
  $ENV{obs_level} = $obs_level;

  print "obs_file = $obs_file\n";

  # Make the output directories
  my $out_dirs = vx_const_get("OUT_DIR") . "/${model}_${domain}/${valid_ymd}/${valid}/pcp_combine " .
                 vx_const_get("OUT_DIR") . "/${model}_${domain}/${valid_ymd}/${valid}/grid_stat " .
                 vx_const_get("OUT_DIR") . "/${model}_${domain}/${valid_ymd}/${valid}/mode";
  vx_run_cmd ( "mkdir -p $out_dirs" );

  # Get the initialization frequency and lead times for this model/domain
  my $init_freq = vx_const_get(uc($model) . "_INIT_FREQ");
  my $lead_max  = max ( vx_util_seq(vx_const_get(uc($model) . "_" . uc($domain) . "_LEAD_SEQ")) );

  # Compute the most recent model initialization time
  my $init_ut  = int( $valid_ut/$init_freq ) * $init_freq;
  my $lead_sec = $valid_ut - $init_ut;

  # The lead time must be at least the accumulation time
  while ( $lead_sec < $accum * 3600 ) {
    $init_ut  -= $init_freq;
    $lead_sec += $init_freq; 
  }

  # Loop over the initialization and lead times for this valid time
  while ( $lead_sec < $lead_max * 3600 ) {

    my $lead_hr = $lead_sec / 3600;
    my $init = strftime ( "%Y%m%d%H", localtime ( $init_ut ) );
    print "\nVerifying the " . $accum . " hr accumulation for the " . $lead_sec/3600 .
          " hr lead of the $init initialization.\n\n";

    # Set up the file template
    $tmpl{model}  = $model;
    $tmpl{domain} = $domain;
    $tmpl{accum}  = $accum;
    $tmpl{init}   = $init;
    $tmpl{valid}  = $valid;

    # Set up a template for the previous time
    my %prev_tmpl = %tmpl;
    $prev_tmpl{valid} = strftime ( "%Y%m%d%H", localtime ( $valid_ut - $accum * 3600 ) );

    # Compute the name of the forecast file to be generated
    $fcst_file = vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_NC_TMPL"),  \%tmpl);

    # For the pme_da, do a subtraction of the runtime accumulation
    if ( substr($model, 0, 6) eq "pme_da" ) {

      # Run PCP-Combine to subtract the runtime accumulations
      vx_run_cmd ( vx_const_get("MET_EXEC") . "/pcp_combine -subtract " .
                   vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_TMPL"),  \%tmpl) . " " .
                   $lead_hr . " " .
                   vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_TMPL"),  \%prev_tmpl) . " " .
                   ( $lead_hr - $accum ) . " $fcst_file"
                 );
    } # end if pme_da

    # For the pme_noda, do a sum of the hourly accumulations
    elsif ( substr($model, 0, 8) eq "pme_noda" ) {

      # Run PCP-Combine to sum up the hourly precipitation to the desired accumulation
      vx_run_cmd ( vx_const_get("MET_EXEC") . "/pcp_combine " .
                   "-sum $init 01 $valid $accum $fcst_file " .
                   "-pcpdir " . vx_const_get("PME_NODA_FCST_DIR") . "/$init"
                 );
    } # end if pme_noda

    # For the pme_wrf22, do a sum of the hourly accumulations
    elsif ( substr($model, 0, 9) eq "pme_wrf22" ) {

      # Run PCP-Combine to sum up the hourly precipitation to the desired accumulation
      vx_run_cmd ( vx_const_get("MET_EXEC") . "/pcp_combine " .
                   "-sum $init 01 $valid $accum $fcst_file " .
                   "-pcpdir " . vx_const_get("PME_WRF22_FCST_DIR") . "/$init"
                 );
    } # end if pme_wrf22

    # For gfs, do either a pass-through or a subtraction
    elsif ( $model eq "gfs" ) {

      # Check if we should do a pass-through
      if ( ( $accum == 6 ) ||
           ( $accum == 3 && $lead_hr % 6 == 3 ) ) {

        # Run PCP-Combine
        vx_run_cmd ( vx_const_get("MET_EXEC") . "/pcp_combine -add " .
                     vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_TMPL"),  \%tmpl) . " " .
                     "$accum $fcst_file"
                   );
      }
      # Otherwise, do a subtraction
      else {

        # Run PCP-Combine
        vx_run_cmd ( vx_const_get("MET_EXEC") . "/pcp_combine -subtract " .
                     vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_TMPL"),  \%tmpl) .
                     " 6 " .
                     vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_TMPL"),  \%prev_tmpl) .
                     " 3 $fcst_file"
                   );
      }
    } # end if gfs

    # Check file existence
    if ( ! -e $fcst_file ) {
      print "WARNING: Expected forecast file does not exist: $fcst_file\n";
    }
    else {

      print "fcst_file = $fcst_file\n";

      # Set environment variables to be used in MET configuration files
      $ENV{vx_mask}  = vx_const_get("GS_" . uc($domain) . "_VX_MASK");
      $ENV{nbr_flag} = "STAT";
      $ENV{case}     = "NBRHD";

      # Run Grid-Stat with neighborhood methods for large masking regions
      vx_run_cmd ( vx_const_get("MET_EXEC") . "/grid_stat $fcst_file $obs_file " .
                   vx_const_get("CONFIG_DIR") . "/GridStatConfig " .
                   "-outdir " . vx_const_get("OUT_DIR") . "/${model}_${domain}/${valid_ymd}/${valid}/grid_stat -v 2" );

      # Only verify over provinces for d02 domain
      if ( $domain eq "d02" ) {

        # Set environment variables to be used in MET configuration files
        $ENV{vx_mask}  = vx_const_get("GS_" . uc($domain) . "_PROV_VX_MASK");
        $ENV{nbr_flag} = "NONE";
        $ENV{case}     = "PROV";

        # Run Grid-Stat a second time with no neighborhood methods for the provinces
        vx_run_cmd ( vx_const_get("MET_EXEC") . "/grid_stat $fcst_file $obs_file " .
                     vx_const_get("CONFIG_DIR") . "/GridStatConfig " .
                     "-outdir " . vx_const_get("OUT_DIR") . "/${model}_${domain}/${valid_ymd}/${valid}/grid_stat -v 2" );
      }

      # Loop through the MODE resolutions to be evaluated
      foreach my $obj_thresh( "LOTHRESH", "HITHRESH" ) {

        # Set environment variables to be used in MET configuration files
        $ENV{obj_thresh}   = $obj_thresh;
        $ENV{conv_thresh}  = vx_const_get("APCP_" . $accum . "_" . $obj_thresh . "_CONV_THRESH");
        $ENV{merge_thresh} = vx_const_get("APCP_" . $accum . "_" . $obj_thresh . "_MERGE_THRESH");

        # Run MODE
        vx_run_cmd ( vx_const_get("MET_EXEC") . "/mode $fcst_file $obs_file " .
                     vx_const_get("CONFIG_DIR") . "/MODEConfig " .
                     "-outdir " . vx_const_get("OUT_DIR") . "/${model}_${domain}/${valid_ymd}/${valid}/mode -v 2" );

        # Zip up the NetCDF output of MODE
        $tmpl{obj_thresh} = $obj_thresh;
        my $nc_file = vx_file_tmpl_gen(vx_const_get("MODE_NC_TMPL"), \%tmpl);
        if ( -e $nc_file ) {
          vx_run_cmd ( "gzip -f $nc_file" );
        }
        else {
          print "Warning: Expected NetCDF output file does not exist: $nc_file\n";
        }
      }
    }

    # Decrement the init time and increment the lead time
    $init_ut  -= $init_freq;
    $lead_sec += $init_freq; 
  }

}

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";
