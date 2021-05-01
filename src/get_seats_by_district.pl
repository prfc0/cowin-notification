#!/usr/bin/perl

use strict;
use warnings;

use Email::Send::SMTP::Gmail;
use Data::Dumper;
use JSON::XS;
use Getopt::Long;

my $send_email;
my @district_ids;
my $gmail_creds_file;
my $to_email;
my $verbose;

GetOptions(
  "send_email!" => \$send_email,
  "district_ids=s@" => \@district_ids,
  "gmail_creds_file=s" => \$gmail_creds_file,
  "to_email=s" => \$to_email,
  "verbose!" => \$verbose,
);

die "Please provide district ids to parse data using --distrcit_ids option.\n" unless @district_ids;
die "Please provide gmail credentials file using --gmail_creds_file option.\n" unless $gmail_creds_file;
die "Please provide to email using --to_email option.\n" unless $to_email;

#my $top_url = "https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?";
my $top_url = "https://api.cowin.gov.in/api/v2/appointment/sessions/public/calendarByDistrict?";

my %data_all;
my %data_18plus;

my @dates = get_dates();

foreach my $date ( @dates ) {
  foreach my $district_id ( @district_ids ) {
    print "Processing for date: $date\n" if $verbose;
    my $url = $top_url . "district_id=$district_id" . "&" . "date=$date";
    my $cmd = "curl '$url'";
    print "$cmd\n" if $verbose;
    chomp( my $op = `$cmd 2>/dev/null` );
    if ( $op =~ /Unauthenticated access/i ) {
      # Sometimes get this error. Skip if this happens.
      print $op, "\n";
      sleep( 1 );
      next;
    }
    # Sleep for 1 second else api can return "Too many requests" error.
    sleep(1);
    my $data = decode_json( $op );
    foreach my $center ( @{$data->{centers}} ) {
      my $name = $center->{name};
      my $center_id = $center->{center_id};
      my $block_name = $center->{block_name};
      my $pincode = $center->{pincode};
      my $fee_type = $center->{fee_type};
      my $state_name = $center->{state_name};
      my $district_name = $center->{district_name};
      foreach my $session ( @{$center->{sessions}} ) {
        my $min_age_limit = $session->{min_age_limit};
        my $date = $session->{date};
        my $available = $session->{available_capacity};
        $data_all{$date}{$center_id} = [ $state_name, $district_name, $block_name, $pincode, $fee_type, $min_age_limit, $available ];
        if ( $min_age_limit != 45 and $available > 0 ) {
          $data_18plus{$date}{$center_id} = [ $state_name, $district_name, $block_name, $pincode, $fee_type, $min_age_limit, $available ];
        }
      }
    }
  }
}

my $data_all = "";
foreach my $date ( sort { $a cmp $b } keys %data_all ) {
  foreach my $center_id ( sort { $a <=> $b } keys %{$data_all{$date}} ) {
    my ( $state_name, $district_name, $block_name, $pincode, $fee_type, $min_age_limit, $available ) = @{$data_all{$date}{$center_id}};
    my $line = "$date,$state_name,$district_name,$block_name,$pincode,$fee_type,$min_age_limit,$available\n";
    print $line;
    $data_all .= $line;
  }
}

my $data_18plus = "";
foreach my $date ( sort { $a cmp $b } keys %data_18plus ) {
  foreach my $center_id ( sort { $a <=> $b } keys %{$data_18plus{$date}} ) {
    my ( $state_name, $district_name, $block_name, $pincode, $fee_type, $min_age_limit, $available ) = @{$data_18plus{$date}{$center_id}};
    my $line = "$date,$state_name,$district_name,$block_name,$pincode,$fee_type,$min_age_limit,$available\n";
    print $line;
    $data_18plus .= $line;
  }
}

my $subject = "List of open slots at various centers.";
my $header = "Date,State,District,Block,Pincode,FeeType,MinAgeLimit,Available\n";
my $email_data = $data_all;
if ( %data_18plus ) {
  $subject = "ALERT: Registration open for 18+";
  $email_data = $data_18plus;
}

my $creds_content;
{
  local $/ = undef;
  open( my $fh, $gmail_creds_file ) or die "$gmail_creds_file : $!";
  $creds_content = <$fh>;
  close( $fh );
}
my $creds_data = decode_json( $creds_content );
my $from_email = $creds_data->{email_id};
my $email_password = $creds_data->{password};

if ( %data_18plus or $send_email ) {
  my ( $mail, $error ) = Email::Send::SMTP::Gmail->new(
                           -smtp  => 'smtp.gmail.com',
                           -login => $from_email,
                           -pass  => $email_password,
  );

  die "Error: $error" unless $mail != -1;

  $mail->send(
           -to      => $to_email,
           -subject => $subject,
           -body    => $email_data,
  );
  $mail->bye;
}

# Get 4 dates per 1 week apart as api returns data for 1 week.
sub get_dates {
  my $time = time;
  my @dates;
  for (1..4) {
    my ( $day, $month, $year ) = (localtime( $time ))[3..5];
    my $date = sprintf "%02d-%02d-%04d", $day, $month+1, $year+1900;
    push @dates, $date;
    $time += 7*24*60*60;
  }
  return @dates;
}
