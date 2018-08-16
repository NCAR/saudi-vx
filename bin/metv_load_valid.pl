#!/usr/bin/perl

################################################################################
#
# Script Name: metv_load_valid.pl
#
#      Author: John Halley Gotway
#              NCAR/RAL/DTC
#
#    Released: 10/31/2012
#
# Description:
#
# Dependencies:
#   The VXUTIL_CONST environment variable must be set to the file containing
#   project constants.
#
# Arguments:
#   - Valid time in YYYMMDDHH format.
#   - List of model to be loaded.
#
# Example:
#   metv_load_valid.pl \
#     2012101523 pme_da_d02 pme_da_d03
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
unless ( scalar @ARGV > 2 ) {
  die "\nERROR: Must have at least 2 arguments: " .
      "valid time, list of models to be loaded\n\n";
}

# Store the valid time
my $valid     = shift @ARGV;
my $valid_ymd = substr($valid, 0, 8);

# Determine the MET version number
# For valid dates >= 2013052412, use V4.1, otherwise use V4.0.
my $metv_load_tmpl = "METV_LOAD_TMPL_V4_0";
if ( vx_date_parse_date($valid) >= vx_date_parse_date("2013052412") ) {
  $metv_load_tmpl = "METV_LOAD_TMPL_V4_1";
}

while ( my $model = shift @ARGV ) {

  print "\n################################################################################\n\n" .
        "Loading data for ${model}/${valid}\n\n";

  # Get the load template file
  my $load_tmpl = vx_const_get($metv_load_tmpl);

  # Get load xml and log file names
  my %tmpl = ( model => $model, valid_ymd => $valid_ymd, valid => $valid );
  my $load_xml = vx_file_tmpl_gen(vx_const_get("METV_LOAD_XML_TMPL"), \%tmpl);

  # Make the output directory if necessary
  my ($load_xml_file, $load_xml_path) = fileparse($load_xml);
  vx_run_cmd ( "mkdir -p $load_xml_path" );

  # Customize the load xml file
  vx_run_cmd ( "cat $load_tmpl | \\
                sed -r \"s/\\{model\\}/$model/\" | \\
                sed -r \"s/\\{valid_ymd\\}/$valid_ymd/\" | \\
                sed -r \"s/\\{valid\\}/$valid/\" > \\
                $load_xml" );

  # Run the load command
  vx_run_cmd ( vx_const_get("METV_LOAD_EXEC") . " $load_xml" );
}

print "\n################################################################################\n\n";

# Print end time
print "\n", $0, " - finished at " . strftime("%Y-%m-%d %H:%M:%S", gmtime()) . "\n\n";
