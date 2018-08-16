#!/usr/bin/perl

use lib "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/lib";

use strict;
use warnings;

use POSIX;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);   
use VxUtil;

# set the valid time, using the argument in YYYYMMDD_HH format, if present
$ENV{'TZ'} = "UTC"; tzset();
my $valid  = ( @ARGV ? shift : "" );

# take the current time, subtract 24 hours, and round down to the neareast 6 hour interval
unless( $valid ){
  my $valid_ut = int( ( strftime( "%s", gmtime() ) - (24 * 3600) ) / (6 * 3600) ) * (6 * 3600);
  $valid = strftime ( "%Y%m%d_%H", localtime ( $valid_ut ) );
}

# check for a 6-hour interval
my $valid_ut = vx_date_parse_date ( $valid );
unless( int($valid_ut % (6 * 3600)) == 0) {
  die("ERROR: Valid time must be a 6-hour interval: $valid\n");
}  

# start the logging mechanism
my $log_file = vx_const_get("LOG_DIR") . "/mon_vx/mon_vx_$valid.log";
vx_log_open($log_file, 1, 0, 0);
vx_log("mon_vx - running at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n");
vx_log("Processing valid time: $valid\n");

# set the cycle time as 2 hours after the valid time
my $cycle_ut = $valid_ut + (2 * 3600);
my $cycle = strftime ( "%Y%m%d%H", localtime ( $cycle_ut ) );

# initialize template
my %tmpl = ( valid => $valid );
$tmpl{cycle} = $cycle;

# initialize counts
my ($missing_point, $found_point, $missing_radar, $found_radar, $missing_model, $found_model) = (0,0,0,0,0,0);

# check the cycle status
vx_log("Checking workflow summary status...\n");
my $run_cmd = vx_const_get("ROCOTOSTAT_EXEC") . " -d " .
              vx_const_get("VX_WORKFLOW_STORE") . " -w " .
              vx_const_get("VX_WORKFLOW_XML") . " -c ${cycle}00 -s";
my $status = qx/$run_cmd/;
vx_log($status);

# check for unfinished tasks 
vx_log("Checking workflow for unfinished tasks...\n");
$run_cmd = vx_const_get("ROCOTOSTAT_EXEC") . " -d " .
           vx_const_get("VX_WORKFLOW_STORE") . " -w " .
           vx_const_get("VX_WORKFLOW_XML") . " -c ${cycle}00" .
           " | egrep -v SUCCEEDED";
$status = qx/$run_cmd/;
vx_log($status);

# check for failed tasks
vx_log("Checking log for failed tasks...");
my $workflow_log = vx_file_tmpl_gen(vx_const_get("VX_WORKFLOW_LOG_TMPL"), \%tmpl);
if ( -e $workflow_log ) {
  $run_cmd = "egrep -i failed " . vx_file_tmpl_gen(vx_const_get("VX_WORKFLOW_LOG_TMPL"), \%tmpl);
  $status = qx/$run_cmd/;
  vx_log($status);
}
else {
  vx_log("  WARNING: Workflow log file does not exist: $workflow_log");
}

# process each of the 6 hourly offsets
for my $offset_hr (1 .. 6) {

  my $cur_ut = $valid_ut - ( $offset_hr * 3600 );
  my $cur = strftime ( "%Y%m%d%H", localtime ( $cur_ut ) );
  $tmpl{valid} = $cur;
  vx_log("\n################################################################################\n");
  vx_log("Checking files for valid time: $cur\n");

  # compute the most recent init time
  my $init_ut = int ( $valid_ut / (6 * 3600) ) * (6 * 3600);
  my $init = strftime ( "%Y%m%d%H", localtime ( $init_ut ) );
  $tmpl{init} = $init;

  # check point observation file
  my $point_obs_file = vx_file_tmpl_gen(vx_const_get("POINT_RAW_TMPL"), \%tmpl);
  if ( -e $point_obs_file ) {
    $found_point += 1;
  }
  else {
    vx_log("  WARNING: Point observation file missing: $point_obs_file");
    $missing_point += 1;
  }

  # check radar data file
  $tmpl{accum} = "01";
  my $radar_obs_file = vx_file_tmpl_gen(vx_const_get("RADAR_RAW_TMPL"), \%tmpl);
  if ( -e $radar_obs_file ) {
    $found_radar += 1;
  }
  else {
    vx_log("  WARNING: Radar observation file missing: $radar_obs_file");
    $missing_radar += 1;
  }

  # check model data files for valid combination of model and domain
  for my $combo ("gfs:d02", "gfs:d03",
                 "pme_da:d02", "pme_da:d03",
                 "pme_noda_c2d02:d02", "pme_noda_c2d03:d02",
                 "pme_wrf22_c2d01:d02") {

    my ($model, $domain) = split(':', $combo);
    $tmpl{model} = $model;
    $tmpl{domain} = $domain;

    # get the initialization freqency
    my $init_freq = vx_const_get(uc($model) . "_INIT_FREQ");
    my @lead_seq  = vx_util_seq(vx_const_get(uc($model) . "_" . uc($domain) . "_LEAD_SEQ"));
    my $lead_max  = max(@lead_seq);
    my $lead_freq = $lead_seq[1] - $lead_seq[0];

    # compute the most recent model initialization time
    $init_ut  = int( $cur_ut / $init_freq ) * $init_freq;
    my $lead_sec = $cur_ut - $init_ut;

    # loop over the initialization and lead times for this valid time
    while ( $lead_sec < $lead_max * 3600 ) {

      my $lead_hr = $lead_sec / 3600;
      $init = strftime ( "%Y%m%d%H", localtime ( $init_ut ) );
      $tmpl{init} = $init;

      # check model file existence
      if( int($cur_ut % ($lead_freq * 3600)) == 0 ) {
        my $model_file = vx_file_tmpl_gen(vx_const_get(uc($model) . "_FCST_TMPL"), \%tmpl);
        if ( -e $model_file ) {
          $found_model += 1;
        }
        else {
          vx_log("  WARNING: $model model file missing: $model_file");
          $missing_model += 1;
        }
      }

      # decrement the init time and increment the lead time
      $init_ut -= $init_freq;
      $lead_sec += $init_freq;

    } # end while

  } # end for combo

} # end for offset_hr

vx_log("\n################################################################################\n");
vx_log("POINT OBS FILES: Found $found_point, Missing $missing_point\n" .
       "RADAR OBS FILES: Found $found_radar, Missing $missing_radar\n" .
       "MODEL FILES    : Found $found_model, Missing $missing_model\n");

# close the logging resources
vx_log("\nmon_model complete at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n");
vx_log_set_email($missing_point || $missing_radar || $missing_model || 1);
vx_log_close("PME_RTFDDA_Vx Status for $valid [MISSING $missing_point point, $missing_radar radar, $missing_model model files]", '${LOG_MON_RECIP}');
