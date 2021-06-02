use 5.010_001;
use strict;
use warnings;

use File::Basename;
use File::Spec::Functions;


use Test::More;

use Text::Table::Read::RelationOn::Tiny;

use constant TEST_DIR => catdir(dirname(__FILE__), 'test-data');


{
  my @set_array = ('this', 'that', 'foo bar', 'empty');
  my %expected_ids;
  for (my $i = 0; $i < @set_array; ++$i) {
    $expected_ids{$set_array[$i]} = $i;
  }

  my $expected = [{
                   1 => {
                         2 => undef
                        },
                   0 => {
                         0 => undef,
                         2 => undef
                        },
                   2 => {
                         1 => undef
                        }
                  },
                  ['this', 'that', 'foo bar', 'empty'],
                  {
                   'this'    => 0,
                   'that'    => 1,
                   'foo bar' => 2,
                   'empty'   => 3
                  }
                 ];

  my $obj = Text::Table::Read::RelationOn::Tiny->new(set => \@set_array);

  ok($obj->prespec, "prespec() returns true");

  is_deeply($obj->elems,      \@set_array,    "elems()");
  is_deeply($obj->elem_ids,   \%expected_ids, "elem_ids()");
  is_deeply($obj->x_elem_ids, \%expected_ids, "x_elem_ids()");

  {
    note("Same order of elements");
    my $input = <<'EOT';

      | x\y     | this | that | foo bar | empty |
      |---------+------+------+---------+-------|
      | this    | X    |      | X       |       |
      |---------+------+------+---------+-------|
      | that    |      |      | X       |       |
      |---------+------+------+---------+-------|
      | foo bar |      | X    |         |       |
      |---------+------+------+---------+-------|
      | empty   |      |      |         |       |
      |---------+------+------+---------+-------|

EOT
    #Don't append a semicolon to the line above!
    my $input_bak = $input;
    is_deeply([$obj->get($input)],
              $expected,
              'Return values of get(STRING) in list context'
             );

    is($input, $input_bak, "Input string not changed");

    is_deeply($obj->elems,      \@set_array,    "elems() unchanged");
    is_deeply($obj->elem_ids,   \%expected_ids, "elem_ids() unchanged");
    is_deeply($obj->x_elem_ids, \%expected_ids, "x_elem_ids()");
    ok($obj->prespec, "prespec() still returns true");
  }

  {
    note("Same relation, rows and cols in table are different from the above");
    my $input = <<'EOT';

      | x\y     | empty | foo bar | this | that |
      |---------+-------+---------+------+------|
      | this    |       | X       | X    |      |
      |---------+-------+---------+------+------|
      | that    |       | X       |      |      |
      |---------+-------+---------+------+------|
      | empty   |       |         |      |      |
      |---------+-------+---------+------+------|
      | foo bar |       |         |      | X    |
      |---------+-------+---------+------+------|

EOT
    #Don't append a semicolon to the line above!
    my $input_bak = $input;
    my $result;

    is_deeply($result=[$obj->get($input)],
              $expected,
              'Return values of get(STRING) in list context'
             );

    is($input, $input_bak, "Input string not changed");

    is_deeply($obj->elems,      \@set_array,    "elems() unchanged");
    is_deeply($obj->elem_ids,   \%expected_ids, "elem_ids() unchanged");
    is_deeply($obj->x_elem_ids, \%expected_ids, "x_elem_ids()");
  }
}


#==================================================================================================
done_testing();
