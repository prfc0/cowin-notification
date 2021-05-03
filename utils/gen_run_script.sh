#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use JSON::XS;

my $config_file;
my $root_dir;
GetOptions(
  "config_file=s" => \$config_file,
  "root_dir=s" => \$root_dir,
);

die "Please provide a config file using --config_file option.\n" unless $config_file;
die "Please provide a root directory using --root_dir option.\n" unless $root_dir;

my $content;
{
  local $/ = undef;
  open( my $fh, $config_file ) or die "$config_file : $!";
  $content = <$fh>;
  close( $fh );
}

my $data = decode_json( $content );

my $src_dir = "$root_dir/src";
my $data_dir = "$root_dir/data";

foreach my $config ( @{$data->{configs}} ) {
    my $district_ids = join( ",", @{$config->{district_ids}} );
    my $email_ids = join( ",", @{$config->{email_ids}} );
    my $cmd = "$src_dir/get_seats_by_district.pl".
              " --district_ids $district_ids".
              " --gmail_creds $data_dir/gmail_creds.json".
              " --to_email $email_ids";
    print "$cmd\n";
}
