package JSCalendar::Duration;
# ABSTRACT - Convert seconds into JSCalendar Durations (Section 3.2.3)

use strict;
use warnings;

use Carp qw(croak);
use Exporter qw(import);

our @EXPORT = qw(seconds_to_duration);

sub seconds_to_duration {
  my $input = shift;

  my ($dec) = $input =~ /\.(\d+)$/;
  my $precision = defined $dec ? length($dec) : 0;

  croak('Usage: seconds_to_duration($seconds). (Extra args provided)')
    if @_;

  my ($durday, $durtime) = ("", "");

  my $days = 0;

  while ($input >= 86400) {
    $days++;
    $input -= 86400;
  }

  $durday = "${days}D" if $days;

  my $hours = 0;

  while ($input >= 3600) {
    $hours++;
    $input -= 3600;
  }

  $durtime = "${hours}H" if $hours;

  my $minutes = 0;

  while ($input >= 60) {
    $minutes++;
    $input -= 60;
  }

  $durtime .= "${minutes}M" if $minutes;

  my $seconds = 0;

  while ($input >= 1) {
    $seconds++;
    $input -= 1;
  }

  $durtime .= "${seconds}" if $seconds;

  # + 0, otherwise 0.0 comes out wrong
  if ($input + 0) {
    my $dec = sprintf("%.${precision}f", $input);

    $dec =~ s/^0+\.//;

    $durtime .= $durtime ? ".${dec}S" : "0.${dec}S";
  } elsif ($seconds) {
    $durtime .= "S";
  }

  # P<zero>D
  return "P0D" unless $durday || $durtime;

  $durtime = "T$durtime" if $durtime;

  return "P" . $durday . $durtime;
}

1;
