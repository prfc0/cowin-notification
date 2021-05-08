#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

my $data_dir;
my $web_dir;
GetOptions(
  "data_dir=s" => \$data_dir,
  "web_dir=s" => \$web_dir,
);

die "Please provide directory from where to copy data using --data_dir option.\n" unless $data_dir;
die "Please provide web directory where to copy data to using --web_dir option.\n" unless $web_dir;

my $latest_file = "";
opendir( DIR, $data_dir ) or die "$data_dir: $!";
while( my $file = readdir( DIR ) ) {
  next unless $file =~ /\.csv$/;
  if ( $file gt $latest_file ) {
    $latest_file = $file;
  }
}
closedir( DIR );
print "latest_file = $latest_file\n";
if ( not -e "$web_dir/data/$latest_file" ) {
  system( "cp $data_dir/$latest_file $web_dir/data" );
  system( "cp $data_dir/$latest_file $web_dir/data/data.csv" );
}
