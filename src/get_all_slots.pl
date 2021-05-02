#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use JSON::XS;

my $cowin_url = "https://api.cowin.gov.in/api/v2";
my $calendar_api_url = "$cowin_url/appointment/sessions/public/calendarByDistrict";

my $district_config_file;
my $log_dir;
GetOptions(
  "district_config_file=s" => \$district_config_file,
  "log_dir=s" => \$log_dir,
);

die "Please provide config file which has details of districts using --district_config_file option.\n" unless $district_config_file;
die "Please provide log directory to store data using --log_dir option.\n" unless $log_dir;

my %district_ids;
open( my $fh, $district_config_file ) or die "$district_config_file: $!";
while( my $line = <$fh> ) {
  chomp( $line );
  next if $line =~ /^State/;
  my ( $state, $state_id, $district, $district_id ) = split( /;/, $line );
  $district_ids{$district_id} = {
    state => $state,
    state_id => $state_id,
    district => $district,
    sort_key => "$state/$district",
  };
}

my ( $date, $date_dir ) = get_date();
my $total = scalar(keys %district_ids);

my $count = 1;
system( "mkdir -p $log_dir/$date_dir" );
foreach my $district_id ( sort { $district_ids{$a}{sort_key} cmp $district_ids{$b}{sort_key} } keys %district_ids ) {
    my $state = $district_ids{$district_id}{state};
    my $district = $district_ids{$district_id}{district};
    print "$count/$total : $state/$district : $district_id\n";
    my $cmd = "curl '$calendar_api_url?district_id=$district_id&date=$date'";
    system( "$cmd > $log_dir/$date_dir/$district_id.json 2>/dev/null" );
    sleep(1);
    $count++;
}

sub get_date {
  my ( $hour, $day, $month, $year ) = ( localtime )[2..5];
  my $date = sprintf "%02d-%02d-%04d", $day, $month+1, $year+1900;
  my $date_dir = sprintf "%04d-%02d-%02d-%02d", $year+1900, $month+1, $day, $hour;
  return $date, $date_dir;
}
