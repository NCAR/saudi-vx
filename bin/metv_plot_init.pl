#!/usr/bin/perl

################################################################################
#
# Script Name: metv_plot_init.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 06/11/2013
#
# Description:
#
# Dependencies:
#   The VXUTIL_CONST environment variable must be set to the file containing
#   project constants.
#
# Arguments:
#   - Initialization time in YYYMMDDHH format.
#
# Example:
#   metv_plot_init.pl 2013061100
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
unless ( scalar @ARGV == 1 ) {
  die "\nERROR: Must have exactly 1 argument: " .
      "initialization time (YYYYMMDDHH) to be plotted\n\n";
}

# Store the current time
my $cur_yyyymmddhh = strftime("%Y%m%d%H", gmtime());

# Store the init time
my $init     = shift @ARGV;
my $init_ut  = vx_date_parse_date($init);
print "Initialization time:\t$init\n";

# Determine the initialization YYYY, YYYYMM, YYYYYMMDD, and HH strings
my $init_yyyy     = strftime("%Y",     vx_date_to_array($init));
my $init_yyyymm   = strftime("%Y%m",   vx_date_to_array($init));
my $init_yyyymmdd = strftime("%Y%m%d", vx_date_to_array($init));
my $init_hh       = strftime("%H", vx_date_to_array($init));
print "Initialization strings:\t$init_yyyy, $init_yyyymm, $init_yyyymmdd, $init_hh\n";

# Determine the day beg and end
my $day_beg = strftime("%Y-%m-%d 00:00:00", vx_date_to_array($init));
my $day_end = strftime("%Y-%m-%d 23:59:59", vx_date_to_array($init));
print "Date range day:  \t( $day_beg to $day_end ) -> Day_$init_yyyymmdd\n";

# Determine the week (Saturday through Friday) beg and end
my $cur_ut = $init_ut;
while($cur_ut > 0) {
  if(strftime("%w", localtime($cur_ut)) == 6) { last; }
  $cur_ut -= 24 * 60 *60;
}
my $week_beg      = strftime("%Y-%m-%d 00:00:00", localtime($cur_ut));
my $week_end      = strftime("%Y-%m-%d 23:59:59", localtime($cur_ut + 6 * 24 * 60 * 60));
my $week_yyyymmdd = strftime("%Y%m%d",            localtime($cur_ut));
print "Date range week:\t( $week_beg to $week_end ) -> Week_$week_yyyymmdd\n";

# Determine the month beg and end
my $month_beg = strftime("%Y-%m-01 00:00:00", vx_date_to_array($init));
my $month_end = strftime("%Y-%m-31 23:59:59", vx_date_to_array($init));
print "Date range month:\t( $month_beg to $month_end ) -> Month_$init_yyyymm\n";

# Determine the season beg and end
my $season_mm       = strftime("%m", vx_date_to_array($init));
my $season_beg_yyyy = strftime("%Y", vx_date_to_array($init));
my $season_end_yyyy = strftime("%Y", vx_date_to_array($init));

# Increment the ending year for December
if($season_mm == "12") {
  $season_end_yyyy += 1;
}

# Assign the correct season
my @season_info;
if($season_mm == "12" || $season_mm == "01" || $season_mm == "02") {
  @season_info = ("Winter", "12", "02");
}
elsif($season_mm == "03" || $season_mm == "04" || $season_mm == "05") {
  @season_info = ("Spring", "03", "05");
}
elsif($season_mm == "06" || $season_mm == "07" || $season_mm == "08") {
  @season_info = ("Summer", "06", "08");
}
else {
  @season_info = ("Fall", "09", "11");
}
my $season_beg = strftime("$season_beg_yyyy-$season_info[1]-01 00:00:00", vx_date_to_array($init));
my $season_end = strftime("$season_end_yyyy-$season_info[2]-31 23:59:59", vx_date_to_array($init));
my $season_str = $season_info[0];
print "Date range season:\t( $season_beg to $season_end ) -> ${season_str}_${season_end_yyyy}\n";

# Determine the year beg and end
my $year_beg = strftime("%Y-01-01 00:00:00", vx_date_to_array($init));
my $year_end = strftime("%Y-12-31 23:59:59", vx_date_to_array($init));
print "Date range year:\t( $year_beg to $year_end ) -> Year_$init_yyyy\n";

print "\n################################################################################\n\n";

# NOTE: Remove this logic once METViewer has been updated to control this via the plot XML
# Remove any existing data files for these plots so that bootstrapping will be redone
vx_run_cmd ( "rm -f " . vx_const_get("METV_DATA_DIR") . "/Week/$week_yyyymmdd/*${init_hh}Z*" );
vx_run_cmd ( "rm -f " . vx_const_get("METV_DATA_DIR") . "/Month/$init_yyyymm/*${init_hh}Z*" );
vx_run_cmd ( "rm -f " . vx_const_get("METV_DATA_DIR") . "/Season/$season_str-$season_end_yyyy/*${init_hh}Z*" );

# Get the plot template file
my %tmpl      = ( init => $init );
my @plot_tmpl = ( vx_const_get("METV_PLOT_CTS_TMPL"),
                  vx_const_get("METV_PLOT_CNT_TMPL"),
                  vx_const_get("METV_PLOT_SID_TMPL") );
my @plot_xml  = ( vx_file_tmpl_gen(vx_const_get("METV_PLOT_CTS_XML_TMPL"), \%tmpl),
                  vx_file_tmpl_gen(vx_const_get("METV_PLOT_CNT_XML_TMPL"), \%tmpl),
                  vx_file_tmpl_gen(vx_const_get("METV_PLOT_SID_XML_TMPL"), \%tmpl) );

# Loop through the XML's to be run
for (my $i=0; $i<scalar(@plot_xml); $i++) {

  # Make the output directory if necessary
  my ($plot_xml_file, $plot_xml_path) = fileparse($plot_xml[$i]);
  vx_run_cmd("mkdir -p $plot_xml_path");

  # Customize the plot xml file
  vx_run_cmd("cat $plot_tmpl[$i] | \\
             sed -r \"s/\\{cur_yyyymmddhh\\}/$cur_yyyymmddhh/\"                                                | \\
             sed -r \"s/\\{init_yyyy\\}/$init_yyyy/\"           | sed -r \"s/\\{init_yyyymm\\}/$init_yyyymm/\" | \\
             sed -r \"s/\\{init_yyyymmdd\\}/$init_yyyymmdd/\"   | sed -r \"s/\\{init_hh\\}/$init_hh/\"         | \\
             sed -r \"s/\\{week_yyyymmdd\\}/$week_yyyymmdd/\"   | sed -r \"s/\\{season_str\\}/$season_str/\"   | \\
             sed -r \"s/\\{day_beg\\}/$day_beg/\"               | sed -r \"s/\\{day_end\\}/$day_end/\"         | \\
             sed -r \"s/\\{week_beg\\}/$week_beg/\"             | sed -r \"s/\\{week_end\\}/$week_end/\"       | \\
             sed -r \"s/\\{month_beg\\}/$month_beg/\"           | sed -r \"s/\\{month_end\\}/$month_end/\"     | \\
             sed -r \"s/\\{season_beg\\}/$season_beg/\"         | sed -r \"s/\\{season_end\\}/$season_end/\"   | \\
             sed -r \"s/\\{season_yyyy\\}/$season_end_yyyy/\"                                                  | \\
             sed -r \"s/\\{year_beg\\}/$year_beg/\"             | sed -r \"s/\\{year_end\\}/$year_end/\"       > \\
             $plot_xml[$i]");

  # Run the plot command
  vx_run_cmd ( vx_const_get("METV_PLOT_EXEC") . " $plot_xml[$i]" );
}

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";

