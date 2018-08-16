#!/usr/bin/perl

use lib "/d1/pmemet/projects/saudi/rtf3h/pmemet/user/lib";

use strict;
use warnings;

use POSIX;
use VxUtil;

# set the init time, using the argument if present
$ENV{'TZ'} = "UTC"; tzset();
my $init  = ( @ARGV ? shift : "" );

# take the current time, subtract one init time, and round down to the nearest init time
my $init_freq = vx_const_get("PME_DA_INIT_FREQ");
unless( $init ){
  my $init_ut = int( ( strftime( "%s", gmtime() ) - $init_freq ) / $init_freq ) * $init_freq;
  $init = strftime ( "%Y%m%d_%H", localtime ( $init_ut ) );
}

# start the logging mechanism
my $log_file = vx_const_get("LOG_DIR") . "/mon_model/mon_model_$init.log";
vx_log_open($log_file, 1, 0, 0);
vx_log("mon_model - running at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n" .
          "INIT: $init\n");

# initialize
my %tmpl = ( init => $init );
my ($total, $missing_nc, $missing_grib, $short_grib) = (0,0,0,0);

# check each domain specified
for my $domain ( vx_const_get("DOMAINS") ){
$tmpl{domain} = $domain;

# check each domain-dependent lead time
for my $lead ( vx_util_seq(vx_const_get("PME_DA_" . uc($domain) . "_LEAD_SEQ")) ){

  # build the file names to monitor
  $tmpl{lead} = $lead;
  my $nc   = vx_file_tmpl_gen(vx_const_get("WRFNC_TMPL"), \%tmpl);
  my $grib = vx_file_tmpl_gen(vx_const_get("GRIB_TMPL"),  \%tmpl);
  $total++;

  # check for existence of the WRF output NetCDF
  my $nc_miss = ( ! -s $nc );
  if( $nc_miss ){
    vx_log("WARNING: WRF NetCDF output file missing  : $nc");
    $missing_nc++;
  }

  # if the UPP GRIB output is also present, continue
  my $grib_miss = ( ! -s $grib );
  $grib_miss and $nc_miss and next;
  if( $grib_miss ){
    vx_log("WARNING: UPP GRIB output file missing    : $grib");
    $missing_grib++;
    next;
  } elsif ( $nc_miss ){
    vx_log("WARNING: UPP GRIB present with no NetCDF : $grib");
  }

  # check the number of records in the GRIB file
  my $wgrib_cmd = vx_const_get("WGRIB_EXEC") . " $grib 2>/dev/null | wc -l";
  my $num_rec = qx/$wgrib_cmd/;
  if( $num_rec != vx_const_get("GRIB_REC") ){
    vx_log("WARNING: UPP GRIB incomplete ($num_rec records): $grib");
    $short_grib++;
  }

} #  END: for $lead

} #  END: for $domain

vx_log("\n# MISSING WRF NetCDF : $missing_nc\n" .
         "# MISSING UPP GRIB   : $missing_grib\n" .
         "# SHORT UPP GRIB     : $short_grib\n");

# close the logging resources
vx_log("\nmon_model complete at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n");
vx_log_set_email($missing_nc || $missing_grib || $short_grib);
vx_log_close("saudi-c3 MODEL $init [MISSING $missing_nc NetCDF $missing_grib GRIB]", '${LOG_MON_RECIP}');

