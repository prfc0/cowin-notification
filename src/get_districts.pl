#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use JSON::XS;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new();
$ua->timeout( 10 );

my $api_url = "https://api.cowin.gov.in/api/v2";
my $get_states_url = "$api_url/admin/location/states";
my $response = $ua->get( $get_states_url );
if ( not $response->is_success ) {
  die $response->status_line;
}
my $states_op = $response->decoded_content;

my %data;
my $states_data = decode_json( $states_op );
foreach my $state ( @{$states_data->{states}} ) {
    my $state_id = $state->{state_id};
    my $state = $state->{state_name};
    my $get_districts_url = "$api_url/admin/location/districts/$state_id";
    my $response = $ua->get( $get_districts_url );
    if ( not $response->is_success ) {
      die $response->status_line;
    }
    my $content = $response->decoded_content;
    my $data = decode_json( $content );
    $data{$state}{state_id} = $state_id;
    foreach my $district ( @{$data->{districts}} ) {
	my $district_id = $district->{district_id};
	my $district_name = $district->{district_name};
	$data{$state}{districts}{$district_name} = $district_id;
    }
}

print "State,StateId,Distrcit,DistrictId\n";
foreach my $state ( sort keys %data ) {
    my $state_id = $data{$state}{state_id};
    foreach my $district ( sort keys %{$data{$state}{districts}} ) {
	my $district_id = $data{$state}{districts}{$district};
	print "$state;$state_id;$district;$district_id\n";
    }
}
