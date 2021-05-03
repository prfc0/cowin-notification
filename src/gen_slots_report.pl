#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use JSON::XS;

my $data_dir;
my $report_file;
GetOptions(
  "data_dir=s" => \$data_dir,
  "report_file=s" => \$report_file,
);

die "Please provide data directory using --data_dir option.\n" unless $data_dir;

open( my $ofh, ">", $report_file ) or die "$report_file: $!";
print $ofh "State,District,Date,Block,Center,Pincode,FeeType,Vaccine,AgeLimit,Available\n";
opendir( DIR, $data_dir ) or die "$data_dir: $!";
while( my $json_file = readdir( DIR ) ) {
  next unless $json_file =~ /^(\d+)\.json$/;
  my $district_id = $1;
  my $content;
  {
     local $/ = undef;
     open( my $fh, "$data_dir/$json_file" ) or die "$data_dir/$json_file : $!";
       $content = <$fh>;
       close( $fh );
  }
  next unless $content;
  my $data = decode_json( $content );
  foreach my $center ( @{$data->{centers}} ) {
    my $center_id = $center->{center_id};
    my $name = $center->{name};
    my $state_name = $center->{state_name};
    my $district_name = $center->{district_name};
    my $block_name = $center->{block_name};
    my $pincode = $center->{pincode};
    my $lat = $center->{lat};
    my $long = $center->{long};
    my $from = $center->{from};
    my $to = $center->{to};
    my $fee_type = $center->{fee_type};
    foreach my $session ( @{$center->{sessions}} ) {
      my $session_id = $session->{session_id};
      my $available_capacity = $session->{available_capacity};
      my $min_age_limit = $session->{min_age_limit};
      my $vaccine = $session->{vaccine};
      my $date = $session->{date};
      if ( $min_age_limit != 45 ) {
        print $ofh qq("$state_name","$district_name",$date,"$block_name","$name",$pincode,$fee_type,$vaccine,$min_age_limit,$available_capacity\n);
      }
    }
  }
}
closedir( DIR );
close( $ofh );
