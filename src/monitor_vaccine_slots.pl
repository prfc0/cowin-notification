#!/usr/bin/perl

$| = 1;

use strict;
use warnings;

use Data::Dumper;
use JSON::XS;
use LWP::UserAgent;
use Email::Send::SMTP::Gmail;

my $COWIN_HOME = $ENV{COWIN_HOME} || die "Please set COWIN_HOME\n";

my $cowin_top_url = "https://api.cowin.gov.in/api/v2";
my $calendar_by_district_url = "$cowin_top_url/appointment/sessions/public/calendarByDistrict";

my $districts_file = "$COWIN_HOME/data/districts.txt";
my %district_ids;
my %districts;
open( my $fh, $districts_file ) or die "$districts_file: $!";
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
  $districts{$district} = $district_id;
}
close( $fh );

my $config_file = "$COWIN_HOME/data/district_user_mapping.json";

my $config_data = get_config_data( $config_file );
my @notification_configs = @{$config_data->{configs}};

my @districts_to_monitor = get_unique_districts( $config_data );
my @dates = get_dates( 1 );

my $ua = LWP::UserAgent->new();

my %prev_data;
my %center_data;

my $style = "border: 1px solid black; border-collapse: collapse;";
my $header = "Book your slot at https://selfregistration.cowin.gov.in/<br><br>".
             "<table style=\"$style\">\n".
             "<tr style=\"$style\">".
             "<th style=\"$style\">Date</th>".
             "<th style=\"$style\">State</th>".
             "<th style=\"$style\">District</th>".
             "<th style=\"$style\">Block</th>".
             "<th style=\"$style\">Center</th>".
             "<th style=\"$style\">Pincode</th>".
             "<th style=\"$style\">FeeType</th>".
             "<th style=\"$style\">Age+</th>".
             "<th style=\"$style\">Available</th>".
             "</tr>\n";
my $subject = "ALERT: Vaccine registration open for 18+";

my $gmail_creds_file = "$COWIN_HOME/data/gmail_creds.json";
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

my %events;
my $first_run = 1;
while( 1 ) {
  my %data = get_district_data( @districts_to_monitor );

  my @mail_data;
  foreach my $date ( sort { $a cmp $b } keys %data ) {
    foreach my $center_id ( sort { $a <=> $b } keys %{$data{$date}} ) {
      if ( exists $prev_data{$date}{$center_id} ) {
        # Means observing it for first time.
        my $availability = $data{$date}{$center_id}{available};
        my $prev_availability = $data{$date}{$center_id}{available};
        if ( $availability == 0 and $prev_availability > 0 ) {
          record_event($center_id, $date, "Center booked completly.");
        }
        if ( $availability > 0 and $prev_availability == 0 ) {
          record_event($center_id, $date, "New slots opened.");
          push @mail_data, [ $center_id, $date, $data{$date}{$center_id} ];
        }
        if ( $availability > $prev_availability ) {
          record_event($center_id, $date, "Vaccine slots increased.");
        } elsif ( $availability < $prev_availability ) {
          record_event($center_id, $date, "Vaccine slots decreased.");
        }

        my $min_age_limit = $data{$date}{$center_id}{min_age_limit};
        my $prev_min_age_limit = $data{$date}{$center_id}{min_age_limit};
        if ( $min_age_limit < 45 and $prev_min_age_limit >= 45 ) {
          record_event($center_id, $date, "Center has started allowing 18-44 people.");
        }
        if ( $min_age_limit >= 45 and $prev_min_age_limit < 45 ) {
          record_event($center_id, $date, "Center has stopped allowing 18-44 people.");
        }
      } elsif ( not $first_run ) {
        record_event($center_id, $date, "New center.");
        push @mail_data, [ $center_id, $date, $data{$date}{$center_id} ];
      }
    }
  }

  foreach my $date ( sort { $a cmp $b } keys %prev_data ) {
    foreach my $center_id ( sort { $a <=> $b } keys %{$prev_data{$date}} ) {
      if ( not exists $data{$date}{$center_id} ) {
        record_event($center_id, $date, "Center is not taking any new appointments.");
      }
    }
  }

  if ( @mail_data ) {
    my ( $mail, $error ) = Email::Send::SMTP::Gmail->new(
                             -smtp  => 'smtp.gmail.com',
                             -login => $from_email,
                             -pass  => $email_password,
    );

    die "Error: $error" unless $mail != -1;

    notify_users( $mail, @mail_data );

    $mail->bye;
  }

  %prev_data = %data;
  $first_run = 0;

  print "Sleeping for 30 seconds.\n";
  sleep( 60 );
}

sub notify_users {
  my ( $mail, @data ) = @_;

  my %mail_data;
  foreach my $mail_data ( @data ) {
    my ( $center_id, $date, $data ) = @$mail_data;
    my $district_id = get_distrcit_from_center( $center_id );
    push @{$mail_data{$district_id}}, $mail_data;
  }

  foreach my $config ( @notification_configs ) {
    my @districts = @{$config->{district_ids}};
    my @email_ids = @{$config->{email_ids}};
    my @mail_data;
    foreach my $district ( @districts ) {
      if ( not exists $mail_data{$district} ) {
        next;
      }
      push @mail_data, @{$mail_data{$district}};
    }
    if ( not @mail_data ) {
      next;
    }
    my $data_all = "";
    foreach my $data ( @mail_data ) {
      my ( $center_id, $date, $data ) = @$data;

      my $min_age_limit = $data->{min_age_limit};
      my $available     = $data->{available};

      my $name          = $center_data{$center_id}{name};
      my $block_name    = $center_data{$center_id}{block_name};
      my $pincode       = $center_data{$center_id}{pincode};
      my $fee_type      = $center_data{$center_id}{fee_type};
      my $state_name    = $center_data{$center_id}{state_name};
      my $district_name = $center_data{$center_id}{district_name};
      my $line = "<tr style=\"$style\">".
                 "<td style=\"$style\" nowrap>$date</td>".
                 "<td style=\"$style\">$state_name</td>".
                 "<td style=\"$style\">$district_name</td>".
                 "<td style=\"$style\">$block_name</td>".
                 "<td style=\"$style\">$name</td>".
                 "<td style=\"$style\">$pincode</td>".
                 "<td style=\"$style\">$fee_type</td>".
                 "<td style=\"$style\">$min_age_limit</td>".
                 "<td style=\"$style\">$available</td>".
                 "</tr>\n";
      #print $line;
      $data_all .= $line;
    }
    my $email_data = $header . $data_all;
    $email_data .= "</table>";
    #print $email_data;
    my $to_email = join( ",", @email_ids );
    $mail->send(
             -to      => $to_email,
             -subject => $subject,
             -body    => $email_data,
             -bcc     => $from_email,
             -contenttype => "text/html",
    );
  }
}

sub get_distrcit_from_center {
  my ( $center_id ) = @_;

  my $district = $center_data{$center_id}{district_name};
  my $district_id = $districts{$district};

  return $district_id;
}

sub record_event {
  my ( $center_id, $date, $event ) = @_;

  my $date_time = get_date_time();

  my $name          = $center_data{$center_id}{name};
  my $block_name    = $center_data{$center_id}{block_name};
  my $pincode       = $center_data{$center_id}{pincode};
  my $fee_type      = $center_data{$center_id}{fee_type};
  my $state_name    = $center_data{$center_id}{state_name};
  my $district_name = $center_data{$center_id}{district_name};

  print "$date_time,$state_name,$district_name,$block_name,$name,$pincode : $event\n";
}

sub get_date_time {
  my ( $sec, $min, $hour, $day, $month, $year ) = (localtime)[0..5];

  return sprintf "%04d/%02d/%02d %02d:%02d:%02d", $year+1900, $month+1, $day, $hour, $min, $sec;
}

sub get_district_data {
  my ( @districts ) = @_;

  my %data;
  foreach my $district_id ( @districts ) {
    my $district_url = "$calendar_by_district_url?district_id=$district_id";
    foreach my $date ( @dates ) {
      my $url .= "$district_url&date=$date";
      my $result = $ua->get( $url );
      if ( not $result->is_success ) {
        print $result->status_line;
        next;
      }
      my $content = $result->decoded_content;
      my $district_data = decode_json( $content );
      foreach my $center ( @{$district_data->{centers}} ) {
        my $center_id = $center->{center_id};
        set_center_data( $center );
        foreach my $session ( @{$center->{sessions}} ) {
          my $min_age_limit = $session->{min_age_limit};
          my $date = $session->{date};
          my $available = $session->{available_capacity};
          if ( $min_age_limit < 45 and $available > 0 ) {
            $data{$date}{$center_id} = {
              min_age_limit => $min_age_limit,
              available => $available
            };
          }
        }
      }
      sleep(1);
    }
  }

  return %data;
}

sub set_center_data {
  my ( $center ) = @_;

  my $center_id = $center->{center_id};
  $center_data{$center_id} = {
    name          => $center->{name},
    block_name    => $center->{block_name},
    pincode       => $center->{pincode},
    state_name    => $center->{state_name},
    district_name => $center->{district_name},
    fee_type      => $center->{fee_type},
  };
}

sub get_dates {
  my ( $num_weeks ) = @_;

  my $time = time;
  my @dates;
  for (1..$num_weeks) {
    my ( $day, $month, $year ) = (localtime( $time ))[3..5];
    my $date = sprintf "%02d-%02d-%04d", $day, $month+1, $year+1900;
    push @dates, $date;
    $time += 7*24*60*60;
  }
  return @dates;
}

sub get_unique_districts {
  my ( $data ) = @_;

  my %districts;
  foreach my $config ( @{$data->{configs}} ) {
    my @districts = @{$config->{district_ids}};
    foreach my $district ( @districts ) {
      $districts{$district} = undef;
    }
  }

  return sort keys %districts;
}

sub get_config_data {
  my ( $file ) = @_;

  my $content;
  {
    local $/ = undef;
    open( my $fh, $file ) or die "$file : $!";
    $content = <$fh>;
    close( $fh );
  }
  my $data = decode_json( $content );

  return $data;
}
