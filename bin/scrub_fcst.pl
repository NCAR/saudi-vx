#!/usr/bin/perl

use lib "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/lib";

use strict;
use warnings;

use POSIX;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);   
use VxUtil;

# get the scrub time, using the argument in YYYYMMDD_HH format, if present
$ENV{'TZ'} = "UTC"; tzset();
my $scrub  = ( @ARGV ? shift : "" );

# take the current time and subtract the number of days to be scrubbed
unless( $scrub ){
  my $scrub_ut = strftime( "%s", gmtime() ) - (86400 * vx_const_get("SCRUB_FCST_DAYS"));
  $scrub = strftime ( "%Y%m%d_%H", localtime ( $scrub_ut ) );
}
my $scrub_ut = vx_date_parse_date ( $scrub );

# start the logging mechanism
my $log_file = vx_const_get("LOG_DIR") . "/scrub_fcst/scrub_fcst_$scrub.log";
vx_log_open($log_file, 1, 0, 0);
vx_log("scrub_fcst - running at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n");
vx_log("Processing scrub time: $scrub\n");

# scrub the gfs4, pme_noda, and pme_wrf22 forecast files
foreach( (vx_const_get("GFS_FCST_DIR"),
          vx_const_get("PME_NODA_FCST_DIR"),
          vx_const_get("PME_NODA_DATA_DIR"),
          vx_const_get("PME_WRF22_FCST_DIR"),
          vx_const_get("PME_WRF22_DATA_DIR")) ) {

  opendir (DIR, $_) or die $!;
  my $cur_ut = 0;
  while (my $cur = readdir(DIR)) {

    # parse date/time based on file name
    if ($cur =~ m/^\d{8}_/ || $cur =~ m/^\d{10}_/) {
      $cur_ut = vx_date_parse_date ( "20" . $cur );
    }
    elsif ($cur =~ m/^\d{10}$/) {
      $cur_ut = vx_date_parse_date ( $cur );
    }
    # skip unrecognized file names
    else {
      next;
    }

    # delete files/directories that are too old
    if($cur_ut < $scrub_ut) {
      vx_log("DELETING: $_/$cur\n");
      qx/rm -rf $_\/$cur/;
    }
    else {
      vx_log("KEEPING:  $_/$cur\n");
    }

  }# end while
} # end foreach

# close the logging resources
vx_log("\nscrub_fcst complete at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n");
