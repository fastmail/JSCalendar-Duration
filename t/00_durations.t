use strict;
use warnings;

use Test::More qw(no_plan);
use JSCalendar::Duration qw(seconds_to_duration);

my @tests = (
  '0'        => 'P0D',
  '0.0'      => 'P0D',
  '.1'       => 'PT0.1S',
  '1'        => 'PT1S',
  '1.0'      => 'PT1S',
  '1.1'      => 'PT1.1S',
  '59'       => 'PT59S',
  '59.8'     => 'PT59.8S',
  '60'       => 'PT1M',
  '61'       => 'PT1M1S',
  '61.1'     => 'PT1M1.1S',
  '3599'     => 'PT59M59S',
  '3599.9'   => 'PT59M59.9S',
  '3600'     => 'PT1H',
  '3601'     => 'PT1H1S',
  '86399'    => 'PT23H59M59S',
  '86400'    => 'P1D',
  '86401'    => 'P1DT1S',
  '172799'   => 'P1DT23H59M59S',
  '172800'   => 'P2D',
  '172801'   => 'P2DT1S',
  '172801.1' => 'P2DT1.1S',
);
  
while (@tests) {
  my ($input, $expect) = (shift @tests, shift @tests);

  is(
    seconds_to_duration($input),
    $expect,
    sprintf("%-10s -> %-10s", $input, $expect),
  );
}
  
done_testing;
