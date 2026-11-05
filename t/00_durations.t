use strict;
use warnings;

use utf8;

use Test::More;
use JSCalendar::Duration qw(
  seconds_to_duration
  duration_to_seconds
);

binmode(Test::More->builder->$_, q{:encoding(UTF-8)})
  for qw(output failure_output todo_output);

# Like is(), but gets the value by calling $code, and treats an exception as a
# failure of this test rather than the end of the whole file.
sub is_lived {
  my ($code, $expect, $desc) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  my $got;
  unless (eval { $got = $code->(); 1 }) {
    my $error = $@;
    fail($desc);
    diag("died: $error");
    return;
  }

  return is($got, $expect, $desc);
}

# Check that $seconds converts to $duration, and that $duration converts back
# to the same number of seconds.
sub round_trip {
  my ($seconds, $duration) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  is_lived(
    sub { seconds_to_duration($seconds) },
    $duration,
    sprintf("%-10s -> %s", $seconds, $duration),
  );

  is_lived(
    sub { duration_to_seconds($duration) + 0 },
    $seconds + 0,
    sprintf("%-10s <- %s", $seconds, $duration),
  );
}

# Check only that $duration parses to $seconds; for valid durations that are
# not what seconds_to_duration would produce, like P1W1D.
sub duration_parses {
  my ($duration, $seconds) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  is_lived(
    sub { duration_to_seconds($duration) + 0 },
    $seconds + 0,
    sprintf("%-10s -> %s", $duration, $seconds),
  );
}


sub duration_rejected {
  my ($input, $error_re) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  my $ok = eval { duration_to_seconds($input); 1 };
  my $error = $@;

  ok(!$ok, "'$input' is rejected")
    and like($error, $error_re, "...with the expected error");
}

sub seconds_rejected {
  my ($input, $error_re) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  my $ok = eval { seconds_to_duration($input); 1 };
  my $error = $@;

  (my $desc = $input) =~ s/\n/\\n/g;

  ok(!$ok, "'$desc' is rejected as seconds")
    and like($error, $error_re, "...with the expected error");
}

subtest "round trips" => sub {
  round_trip('0',        'P0D');
  round_trip('0.0',      'P0D');
  round_trip('0.00',     'P0D');
  round_trip('0.050',    'PT0.05S');
  round_trip('0.1',      'PT0.1S');
  round_trip('.1',       'PT0.1S');
  round_trip('1',        'PT1S');
  round_trip('1.0',      'PT1S');
  round_trip('1.1',      'PT1.1S');
  round_trip('1.01',     'PT1.01S');
  round_trip('1.10',     'PT1.1S');
  round_trip('1.50',     'PT1.5S');
  round_trip('59',       'PT59S');
  round_trip('59.8',     'PT59.8S');
  round_trip('60',       'PT1M');
  round_trip('60.5',     'PT1M0.5S');
  round_trip('60.00',    'PT1M');
  round_trip('61',       'PT1M1S');
  round_trip('61.1',     'PT1M1.1S');
  round_trip('3599',     'PT59M59S');
  round_trip('3599.9',   'PT59M59.9S');
  round_trip('3600',     'PT1H');
  round_trip('3600.000', 'PT1H');
  round_trip('3600.10',  'PT1H0M0.1S');
  round_trip('3600.5',   'PT1H0M0.5S');
  round_trip('3601',     'PT1H0M1S');
  round_trip('3659',     'PT1H0M59S');
  round_trip('3660.5',   'PT1H1M0.5S');
  round_trip('7200',     'PT2H');
  round_trip('7201.1',   'PT2H0M1.1S');
  round_trip('86399',    'PT23H59M59S');
  round_trip('86400',    'P1D');
  round_trip('86400.0',  'P1D');
  round_trip('86400.5',  'P1DT0.5S');
  round_trip('86401',    'P1DT1S');
  round_trip('86460.25', 'P1DT1M0.25S');
  round_trip('90001',    'P1DT1H0M1S');
  round_trip('90000.5',  'P1DT1H0M0.5S');
  round_trip('172799',   'P1DT23H59M59S');
  round_trip('172800',   'P2D');
  round_trip('172801',   'P2DT1S');
  round_trip('172801.1', 'P2DT1.1S');
  round_trip('604800',   'P1W');
  round_trip('604800.0', 'P1W');
  round_trip('604800.5', 'P7DT0.5S');
  round_trip('604801',   'P7DT1S');
  round_trip('691200',   'P8D');
  round_trip('1209600',    'P2W');
  round_trip('1209600.25', 'P14DT0.25S');
};

subtest "valid but non-canonical durations" => sub {
  duration_parses('P0W',              0);
  duration_parses('P1W0D',            604800);
  duration_parses('P1W1D',            691200);
  duration_parses('P1WT1H',           608400);
  duration_parses('P1WT0.5S',         604800.5);
  duration_parses('P2W3DT4H5M6.7S',   1483506.7);
  duration_parses('P1W1DT1H0M1S',     694801);
};

subtest "misplaced weeks" => sub {
  duration_rejected('P1D1W',  qr{expected T here: '1W'});
  duration_rejected('P1W1W',  qr{expected T here: '1W'});
  duration_rejected('PT1W',   qr{confused by '1W'});
  duration_rejected('P1W1DT', qr{no components after 'T'});
  duration_rejected('P1WT',   qr{no components after 'T'});
};

subtest "non-ASCII" => sub {
  # ๓ - U+00E53 - THAI DIGIT THREE
  duration_rejected("P\N{THAI DIGIT THREE}D", qr/ASCII/);
};

subtest "empty components" => sub {
  duration_rejected('P',    qr{no components after 'P'});
  duration_rejected('PT',   qr{no components after 'T'});
  duration_rejected('P1DT', qr{no components after 'T'});
};

subtest "trailing zero" => sub {
  duration_rejected('P1D0',    qr{expected T here: '0'});
  duration_rejected('PT1H0',   qr{confused by '0'});
  duration_rejected('P1DT1H0', qr{confused by '0'});
};

subtest "invalid seconds" => sub {
  my $non_number = qr{Non-number value provided};

  seconds_rejected("60\n",   $non_number);
  seconds_rejected("60.5\n", $non_number);
  seconds_rejected(" 60",    $non_number);
  seconds_rejected("60 ",    $non_number);
  seconds_rejected("-60",    $non_number);
  seconds_rejected("+60",    $non_number);
  seconds_rejected("1e3",    $non_number);
  seconds_rejected("1.2.3",  $non_number);
  seconds_rejected("1.",     $non_number);
  seconds_rejected("abc",    $non_number);
  seconds_rejected("abc.5",  $non_number);

  seconds_rejected("\N{THAI DIGIT THREE}",   $non_number);
  seconds_rejected("1.\N{THAI DIGIT THREE}", $non_number);
};

done_testing;
