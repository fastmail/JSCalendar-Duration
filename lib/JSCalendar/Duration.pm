package JSCalendar::Duration;
# ABSTRACT: Convert seconds to JSCalendar durations and back

use strict;
use warnings;

use Carp qw(croak);
use Exporter qw(import);

our @EXPORT = qw(seconds_to_duration duration_to_seconds);
our @EXPORT_OK = qw(seconds_to_signed_duration signed_duration_to_seconds);

sub duration_to_seconds {
  my $input = shift;

  croak("Usage: duration_to_seconds(\$duration). (Extra args provided: @_)")
    if @_;

  croak('Usage: duration_to_seconds($duration)')
    unless defined $input;

  return _duration_to_seconds($input, $input);
}

# Convert $toparse, an unsigned duration, to seconds.  $input is what the
# public function was given, which may have more to it than $toparse, and is
# used in error messages.
sub _duration_to_seconds {
  my ($input, $toparse) = @_;

  # Let's get that out of the way
  return '0' if $toparse eq 'P0D';

  my $seconds = 0;

  if ($toparse =~ /\P{ASCII}/) {
    croak("Invalid duration '$input', must be entirely ASCII");
  }

  unless ($toparse =~ s/^P//) {
    croak("Invalid duration '$input', must start with 'P'");
  }

  unless (length $toparse) {
    croak("Invalid duration '$input', no components after 'P'");
  }

  # RFC 8984 allows weeks to be followed by days and a time component, unlike
  # RFC 5545 and earlier JSCalendar drafts, where weeks had to stand alone.
  if ($toparse =~ s/^(\d+)W//) {
    $seconds += (86400 * 7 * $1);
  }

  if ($toparse =~ s/^(\d+)D//) {
    $seconds += (86400 * $1);
  }

  return $seconds unless length $toparse;

  unless ($toparse =~ s/^T//) {
    croak("Invalid duration '$input', expected T here: '$toparse'");
  }

  unless (length $toparse) {
    croak("Invalid duration '$input', no components after 'T'");
  }

  my ($has_hours, $has_minutes);

  if ($toparse =~ s/^(\d+)H//) {
    $seconds += (3600 * $1);
    $has_hours = 1;
  }

  if ($toparse =~ s/^(\d+)M//) {
    $seconds += (60 * $1);
    $has_minutes = 1;
  }

  if ($toparse =~ s/^(\d+(\.\d+)?)S//) {
    my ($value, $fraction) = ($1, $2);

    # In the grammar, dur-hour may only be followed by dur-minute, so seconds
    # can't come right after hours: PT1H1S must be PT1H0M1S.
    if ($has_hours && !$has_minutes) {
      croak("Invalid duration '$input', seconds may not follow hours without minutes");
    }

    # RFC 8984: "Fractional second values MUST NOT have trailing zeros", and
    # that includes a fraction of all zeros.
    if (defined $fraction && $fraction =~ /0\z/) {
      croak("Invalid duration '$input', fractional seconds may not end in zero");
    }

    $seconds += $value;
  }

  if (length $toparse) {
    croak("Invalid duration '$input': confused by '$toparse'");
  }

  return $seconds;
}

sub seconds_to_duration {
  my $input = shift;

  croak("Usage: seconds_to_duration(\$seconds). (Extra args provided: @_)")
    if @_;

  croak('Usage: seconds_to_duration($seconds)')
    unless defined $input;

  return _seconds_to_duration('seconds_to_duration', $input, $input);
}

# Convert $toparse, a non-negative number of seconds, to a duration.  $input is
# what the public function, named by $func, was given, which may have more to
# it than $toparse, and both are used in error messages.
sub _seconds_to_duration {
  my ($func, $input, $toparse) = @_;

  unless (length $toparse) {
    croak("Usage: $func(\$seconds). (Non-number value provided: '$input')");
  }

  my $dec = q{};

  # RFC 8984 forbids trailing zeros in the fraction, and forbids a fraction
  # that is entirely zero, so we drop them, possibly leaving nothing.
  if ($toparse =~ s/\.([0-9]+)\z//) {
    ($dec = $1) =~ s/0+\z//;
  }

  # .1 becomes "", we want 0 after
  $toparse ||= 0;

  if ($toparse && $toparse !~ /\A[0-9]+\z/) {
    croak("Usage: $func(\$seconds). (Non-number value provided: '$input')");
  }

  # Compare as strings before doing arithmetic, so oversized inputs cannot
  # overflow or lose precision.  This limit is exact even on floating-point
  # Perl builds; the fractional part is kept separately as a string.
  $toparse =~ s/\A0+(?=[0-9])//;
  my $max_seconds = '9007199254740991'; # 2**53 - 1
  if (length($toparse) > length($max_seconds)
      || (length($toparse) == length($max_seconds) && $toparse gt $max_seconds)) {
    croak("Usage: $func(\$seconds). (Whole seconds exceed $max_seconds: '$input')");
  }

  my ($durday, $durtime) = ("", "");

  # This division may be done in floating point, where the quotient can be
  # inexact.  It is still safe to truncate: below 2**53, the rounding error is
  # always less than 1/86400, the smallest amount by which a quotient can fall
  # short of the next whole day, so it can never round up to it.  Raising
  # $max_seconds would break this.
  my $days = int($toparse / 86400);
  $toparse %= 86400;

  if ($days && $days % 7 == 0 && $toparse == 0 && !length $dec) {
    return 'P' . ($days/7) . "W";
  }

  $durday = "${days}D" if $days;

  my $hours = int($toparse / 3600);
  $toparse %= 3600;

  $durtime = "${hours}H" if $hours;

  my $minutes = int($toparse / 60);
  my $seconds = $toparse % 60;

  # The grammar only permits seconds after minutes, so if we have hours and
  # seconds, we need minutes even if there are zero of them.
  $durtime .= "${minutes}M" if $minutes || ($hours && ($seconds || length $dec));

  if (length $dec) {
    $durtime .= "${seconds}.${dec}S";
  } elsif ($seconds) {
    $durtime .= "${seconds}S";
  }

  # P<zero>D
  return "P0D" unless $durday || $durtime;

  $durtime = "T$durtime" if $durtime;

  return "P" . $durday . $durtime;
}

sub signed_duration_to_seconds {
  my $input = shift;

  croak("Usage: signed_duration_to_seconds(\$duration). (Extra args provided: @_)")
    if @_;

  croak('Usage: signed_duration_to_seconds($duration)')
    unless defined $input;

  my ($sign, $duration) = $input =~ /\A([-+]?)(.*)\z/s;

  my $seconds = _duration_to_seconds($input, $duration);

  return($sign eq '-' && $seconds != 0 ? -$seconds : $seconds);
}

sub seconds_to_signed_duration {
  my $input = shift;

  croak("Usage: seconds_to_signed_duration(\$seconds). (Extra args provided: @_)")
    if @_;

  croak('Usage: seconds_to_signed_duration($seconds)')
    unless defined $input;

  my ($sign, $seconds) = $input =~ /\A([-+]?)(.*)\z/s;

  my $duration = _seconds_to_duration(
    'seconds_to_signed_duration',
    $input,
    $seconds,
  );

  return($sign eq '-' && $duration ne 'P0D' ? "-$duration" : $duration);
}

1;
__END__

=head1 SYNOPSIS

  use JSCalendar::Duration qw(
    seconds_to_duration
    duration_to_seconds
  );

  # 104403.1
  my $seconds = duration_to_seconds("P1DT5H0M3.1S");

  # P1D
  my $duration = seconds_to_duration('86400');

=head1 DESCRIPTION

This module converts between a duration of time as specified by seconds and
a JSCalendar Duration or SignedDuration, as defined in RFC 8984 sections 1.4.6
and 1.4.7.

=head1 EXPORTS

=head2 seconds_to_duration

  my $duration = seconds_to_duration("86401.2");

Converts seconds to a JSCalendar duration representation.

The whole seconds must not exceed 9007199254740991 (2**53 - 1), the largest
integer in the portable exact integer range.  Larger values throw an exception.
Fractional seconds are handled separately and do not count toward this limit.

=head2 duration_to_seconds

  my $seconds = duration_to_seconds("P1DT4H");

Converts a JSCalendar duration to seconds.

=head1 OPTIONAL EXPORTS

These are not exported by default, but can be requested by name.

=head2 seconds_to_signed_duration

  # -PT15M
  my $duration = seconds_to_signed_duration(-900);

Converts seconds, which may be negative, to a JSCalendar SignedDuration.
Negative values get a leading C<->.  Positive values and zero get no sign.
The magnitude has the same whole-seconds limit as C<seconds_to_duration>.

=head2 signed_duration_to_seconds

  # -900
  my $seconds = signed_duration_to_seconds("-PT15M");

Converts a JSCalendar SignedDuration, which may have a leading C<+> or C<->,
to seconds, which will be negative if the duration had a leading C<->.

=head1 SEE ALSO

=over 4

=item L<https://www.rfc-editor.org/rfc/rfc8984.html#section-1.4.6>

The JSCalendar Duration type, in RFC 8984.

=item L<https://www.rfc-editor.org/rfc/rfc8984.html#section-1.4.7>

The JSCalendar SignedDuration type, in RFC 8984.

=back

=cut
