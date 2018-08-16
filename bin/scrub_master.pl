#!/usr/bin/perl

use lib "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/lib";

use strict;
use warnings;

use POSIX;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);   
use VxUtil;

# start the logging mechanism
my $log_file = vx_const_get("LOG_DIR") . "/scrub_master/scrub_master_" . strftime("%Y%m%d_%H", gmtime()) . ".log";
vx_log_open($log_file, 1, 0, 0);
vx_log("scrub_master - running at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n");

# scrub forecast directories: gfs4, pme_noda, and pme_wrf22 forecast files
foreach( (vx_const_get("GFS_FCST_DIR"),
          vx_const_get("PME_NODA_FCST_DIR"),
          vx_const_get("PME_NODA_DATA_DIR"),
          vx_const_get("PME_WRF22_FCST_DIR"),
          vx_const_get("PME_WRF22_DATA_DIR")) ) {
  vx_log("Running forecast data scrubber for $_ ...\n");
  my $run_cmd = vx_const_get("SCRUB_EXEC") . " -dv " .
                vx_const_get("SCRUB_FCST_DAYS") . " $_";
  vx_log($run_cmd);
  my $status = qx/$run_cmd/;
  vx_log($status);
}
# scrub observation directories: point and radar
foreach( (vx_const_get("POINT_OBS_DIR"),
          vx_const_get("RADAR_DATA_DIR"),
          vx_const_get("RADAR_OBS_DIR")) ) {
  vx_log("Running observation data scrubber for $_ ...\n");
  my $run_cmd = vx_const_get("SCRUB_EXEC") . " -dv " .
                vx_const_get("SCRUB_OBS_DAYS") . " $_";
  vx_log($run_cmd);
  my $status = qx/$run_cmd/;
  vx_log($status);
}
# scrub MET output directories
foreach( (vx_const_get("OUT_DIR")) ) {
  vx_log("Running MET output data scrubber for $_ ...\n");
  my $run_cmd = vx_const_get("SCRUB_EXEC") . " -dv " .
                vx_const_get("SCRUB_MET_OUT_DAYS") . " $_";
  vx_log($run_cmd);
  my $status = qx/$run_cmd/;
  vx_log($status);
}
# scrub plotting directories
foreach( (vx_const_get("METV_DIR")) ) {
  vx_log("Running plot data scrubber for $_ ...\n");
  my $run_cmd = vx_const_get("SCRUB_EXEC") . " -dv " .
                vx_const_get("SCRUB_PLOT_DAYS") . " $_";
  vx_log($run_cmd);
  my $status = qx/$run_cmd/;
  vx_log($status);
} 
# scrub log file directories
foreach( (vx_const_get("LOG_DIR")) ) {
  vx_log("Running log data scrubber for $_ ...\n");
  my $run_cmd = vx_const_get("SCRUB_EXEC") . " -dv " .
                vx_const_get("SCRUB_LOG_DAYS") . " $_";
  vx_log($run_cmd);
  my $status = qx/$run_cmd/;
  vx_log($status);
}
# scrub METViewer database
vx_log("Running METViewer scrubber for mv_saudi_gwpme ...\n");

# take the current time and subtract the number of days to be scrubbed
my $scrub_ut = strftime( "%s", gmtime() ) - (86400 * vx_const_get("SCRUB_METV_DB_DAYS"));
my $scrub = strftime ( "%Y-%m-%d %H:%M:%S", localtime ( $scrub_ut ) );
my $run_cmd = vx_const_get("METV_SCRUB_EXEC") . " " .
              vx_const_get("METV_SCRUB_SQL") .
              " mv_saudi_gwpme fcst_init_beg \"'2000-01-01 00:00:00'\" \"'" . $scrub . "'\"";
vx_log($run_cmd);
my $status = qx/$run_cmd/;
vx_log($status);

# close the logging resources
vx_log("\nscrub_master complete at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n");

