#!/usr/bin/perl

use strict;
use warnings;

use JSON::XS;

my %district_ids;
my $districts_file = "../data/districts.txt";
open( my $fh, $districts_file ) or die "$districts_file: $!";
while( my $line = <$fh> ) {
  chomp( $line );
  next if $line =~ /^State/;
  my ( $state, $state_id, $district, $district_id ) = split( /;/, $line );
  $district_ids{$district_id} = {
    state => $state,
    state_id => $state_id,
    district => $district,
  };
}
close( $fh );
my $config_file = "../data/district_user_mapping.json";

my $content;
{
  local $/ = undef;
  open( my $fh, $config_file ) or die "$config_file: $!";
  $content = <$fh>;
  close( $fh );
}
my $data = decode_json( $content );
foreach my $config ( @{$data->{configs}} ) {
  my @email_ids = @{$config->{email_ids}};
  my @district_ids = @{$config->{district_ids}};
  my @districts;
  foreach my $district_id ( @district_ids ) {
    my $district = $district_ids{$district_id}{district};
    push @districts, $district;
  }
  my $districts = join( ",", @districts );
  foreach my $email_id ( @email_ids ) {
    print "$email_id: $districts\n";
  }
}
