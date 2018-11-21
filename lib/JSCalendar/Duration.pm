package JSCalendar::Duration;
# ABSTRACT - Convert seconds into JSCalendar Durations (Section 3.2.3)

use strict;
use warnings;

use Carp qw(croak);
use Exporter qw(import);

our @EXPORT = qw(seconds_to_duration duration_to_seconds);

sub duration_to_seconds {
  my $input = shift;

  croak("Usage: duration_to_seconds(\$seconds). (Extra args provided: @_)")
    if @_;

  croak('Usage; durations_to_seconds($duration)')
    unless defined $input;

  # Let's get that out of the way
  return '0' if $input eq 'P0D';

  my $toparse = $input;

  my $seconds = 0;

  unless ($toparse =~ s/^P//) {
    croak("Invalid duration '$input', must start with 'P'");
  }

  if ($toparse =~ s/^(\d+)D//) {
    $seconds += (86400 * $1);
  }

  return $seconds unless $toparse;

  unless ($toparse =~ s/^T//) {
    croak("Invalid duration '$input', expected T here: '$toparse'");
  }

  if ($toparse =~ s/^(\d+)H//) {
    $seconds += (3600 * $1);
  }

  if ($toparse =~ s/^(\d+)M//) {
    $seconds += (60 * $1);
  }

  if ($toparse =~ s/^(\d+(?:\.\d+)?)S//) {
    $seconds += $1;
  }

  if ($toparse) {
    croak("Invalid duration '$input': confused by '$toparse'");
  }

  return $seconds;
}

sub seconds_to_duration {
  my $input = shift;

  croak("Usage: seconds_to_duration(\$seconds). (Extra args provided: @_)")
    if @_;

  croak('Usage; durations_to_seconds($duration)')
    unless defined $input;

  my $toparse = $input;

  my $dec;

  $dec = $1 if $toparse =~ s/\.(\d+)$//;

  # .1 becomes "", we want 0 after
  $toparse ||= 0;

  if ($toparse && $toparse !~ /^\d+$/) {
    croak("Usage: seconds_to_duration(\$seconds). (Non-number value provided: '$input'");
  }

  my ($durday, $durtime) = ("", "");

  my $days = 0;

  while ($toparse >= 86400) {
    $days++;
    $toparse -= 86400;
  }

  $durday = "${days}D" if $days;

  my $hours = 0;

  while ($toparse >= 3600) {
    $hours++;
    $toparse -= 3600;
  }

  $durtime = "${hours}H" if $hours;

  my $minutes = 0;

  while ($toparse >= 60) {
    $minutes++;
    $toparse -= 60;
  }

  $durtime .= "${minutes}M" if $minutes;

  my $seconds = 0;

  while ($toparse >= 1) {
    $seconds++;
    $toparse -= 1;
  }

  $durtime .= "${seconds}" if $seconds;

  if ($dec) {
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
