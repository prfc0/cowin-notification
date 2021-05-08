#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use Text::CSV;

my $q = CGI->new();
print $q->header();

print "<!DOCTYPE html>\n";
print "<html lang=\"en\">\n";
print "<head>\n";
print "<title>Co-WIN Slots Availability for 18-44</title>\n";
print qq(<meta name="viewport" content="width=device-width, initial-scale=2.0">\n);
print "<link rel=\"icon\" type=\"image/png\" href=\"images/favicon.ico\">\n";
print "<link rel='stylesheet' href='tablefilter/style/tablefilter.css'>\n";
print "<link href=\"https://fonts.googleapis.com/css2?family=Source+Code+Pro&display=swap\" rel=\"stylesheet\">\n";
print "<style>
body {
  font-family: Verdana;
}
th {
  font-family: 'Source Code Pro', monospace;
  font-size: 14px;
  font-weight: bold;
  font-variant: small-caps;
}
td, pre {
  font-family: 'Source Code Pro', monospace;
  font-size: 12px;
}
</style>";
print "
<!-- Global site tag (gtag.js) - Google Analytics -->
<script async src=\"https://www.googletagmanager.com/gtag/js?id=G-NCFCHNHJZD\"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'G-NCFCHNHJZD');
</script>
";
print "</head>\n";
print "<body>\n";
print "<h1>Know when Covid-19 vaccine slots become available (18-44).</h1>\n";

print "<h3>Use the filters to check whether any vaccination slots are available in your city / areas of choice.</h3>\n";

print "<h3>Click the drop-down buttons to sort or use the open boxes to type the city name of your choice.</h3>\n";

print "<p>Disclaimer: The data is sourced from <a href=\"https://apisetu.gov.in/public/marketplace/apicowin/cowin-public-v2\" target=\"_blank\">Cowin APIs.</a> This is not an official portal. It's being done on a pilot, non-commercial and best-effort basis by tech, design & policy friends: Ankur Gupta, Sandhya Kannan and Akhilesh Tilotia. We take no responsibility for completeness or accuracy of data.<br>\n";
print "We will try to add more features and alerts over time. In case any of you are interested in helping us out, please do contact us <a href=\"https://atilotia.com/contact\" target=\"_blank\">here</a>.</p>";
print "<hr>\n";
print "<table id=\"cowin\">\n";

my $file = "data/data.csv";
my $csv = Text::CSV->new( { binary => 1 } ) or die "Cannot use CSV: " . Text::CSV->error_diag();
open( my $fh, "<:encoding(utf8)", $file ) or die "$file : $!";
my $row = $csv->getline( $fh );
#open( my $fh, $file ) or die $!;
#chomp( my $line = <$fh> );
my @fields = @$row;
@fields = ( @fields[0..7], $fields[9] );
print "<thead>\n";
print "<tr>\n";
foreach my $field ( @fields ) {
  print "<th nowrap>$field</th>\n";
}
print "</tr>\n";
print "</thead>\n";
print "<tbody>\n";
my %data;
#while( my $line = <$fh> ) {
while( my $row = $csv->getline( $fh ) ) {
  my @fields = @$row;
#  next if $fields[9] == 0;
  @fields = ( @fields[0..7], $fields[9] );
  my ( $s, $t, $d, $b, $c ) = @fields[0..4];
  $data{$s}{$t}{$d}{$b}{$c} = [ @fields[5..8] ];
}
close( $fh );

foreach my $s ( sort keys %data ) {
  foreach my $t ( sort keys %{$data{$s}} ) {
    foreach my $d ( sort keys %{$data{$s}{$t}} ) {
      foreach my $b ( sort keys %{$data{$s}{$t}{$d}} ) {
        foreach my $c ( sort keys %{$data{$s}{$t}{$d}{$b}} ) {
          my @fields = @{$data{$s}{$t}{$d}{$b}{$c}};
          print "<tr>\n";
          print "<td nowrap>$s</td>\n";
          print "<td nowrap>$t</td>\n";
          print "<td nowrap>$d</td>\n";
          print "<td nowrap>$b</td>\n";
          print "<td nowrap>$c</td>\n";
          foreach my $field ( @fields ) {
            print "<td nowrap>$field</td>\n";
          }
          print "</tr>\n";
        }
      }
    }
  }
}
print "</tbody>\n";
print "</table>\n";
my $last_updated = calc_last_updated( $file );
print "<pre>Data was last updated $last_updated ago.</pre>\n";
print "</body>\n";
print "</html>\n";
print "<script src='tablefilter/tablefilter.js'></script>\n";
print "<script src='cowin.2.js'></script>\n";

sub calc_last_updated {
  my ( $file ) = @_;
  my $mtime = (stat( $file ))[9];
  my $elapsed = time - $mtime;
  my $hour = int($elapsed/3600);
  my $min = int(($elapsed%3600)/60);
  my $sec = $elapsed%60;
  my $last_updated = sprintf "%02d:%02d:%02d", $hour, $min, $sec;
  return $last_updated;
}
