use 5.010_001;
use strict;
use warnings;

use File::Basename;
use File::Spec::Functions;


use Test::More;

use Text::Table::Read::RelationOn::Tiny;

use constant TEST_DIR => catdir(dirname(__FILE__), 'test-data');


{
  my @set_array = ('this', ['that'], 'foo bar', ['empty']);
  my @set_elems = ('this',  'that' , 'foo bar',  'empty' );
  my %expected_ids;
  for (my $i = 0; $i < @set_elems; ++$i) {
    $expected_ids{$set_elems[$i]} = $i;
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
                  [@set_elems],
                  {
                   'this'    => 0,
                   'that'    => 1,
                   'foo bar' => 2,
                   'empty'   => 3
                  }
                 ];

  my $obj = Text::Table::Read::RelationOn::Tiny->new(set => \@set_array);

  ok($obj->prespec, "prespec() returns true");

  is_deeply($obj->elems,      \@set_elems,    "elems()");
  is_deeply($obj->elem_ids,   \%expected_ids, "elem_ids()");
  is_deeply($obj->x_elem_ids, \%expected_ids, "x_elem_ids()");
  is($obj->n_elems, 4, "n_elems()");

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

    is_deeply($obj->elems,      \@set_elems,    "elems() unchanged");
    is_deeply($obj->elem_ids,   \%expected_ids, "elem_ids() unchanged");
    is_deeply($obj->x_elem_ids, \%expected_ids, "x_elem_ids()");
    is($obj->n_elems, 4, "n_elems()");
    ok($obj->prespec, "prespec() still returns true");
  }
}

{
  my @set_array = ([qw(a a1 a2 a3)], 'b', [qw(c c1)], ['d']);
  my @set_elems = ( qw(a b c d a1 a2 a3 c1) );
  my $obj = Text::Table::Read::RelationOn::Tiny->new(set => \@set_array);
  ok($obj->prespec, "prespec() returns true");
  is($obj->n_elems, 4, "n_elems()");
  is_deeply($obj->elems, \@set_elems, 'elems()');
  is_deeply($obj->elem_ids, {'a'  => 0,
                             'a1' => 0,
                             'a2' => 0,
                             'a3' => 0,
                             'b'  => 1,
                             'c'  => 2,
                             'c1' => 2,
                             'd'  => 3
                            },
            'elem_ids()');
  is_deeply($obj->x_elem_ids, {a  => 0,
                               b  => 1,
                               c  => 2,
                               d  => 3,
                               a1 => 4,
                               a2 => 5,
                               a3 => 6,
                               c1 => 7
                              },
            'x_elem_ids');


  my $input = <<'EOT';
      | x\y | a | b | c | d |
      |-----+---+---+---+---|
      | a   | X | X | X | X |
      |-----+---+---+---+---|
      | b   |   | X | X | X |
      |-----+---+---+---+---|
      | c   |   |   | X | X |
      |-----+---+---+---+---|
      | d   |   |   |   | X |
      |-----+---+---+---+---|
EOT
    #Don't append a semicolon to the line above!

  $obj->get($input);

  is_deeply($obj->elem_ids, { a => 0, a1 => 0, a2 => 0, a3 => 0,
                              b => 1,
                              c => 2, c1 => 2,
                              d => 3
                            },
            'elem_ids()');

  is_deeply($obj->x_elem_ids, { a  => 0,
                                a1 => 4,
                                a2 => 5,
                                a3 => 6,
                                b  => 1,
                                c  => 2,
                                c1 => 7,
                                d  => 3
                              },
            'x_elem_ids()');


  is_deeply($obj->matrix,
            {
             0 => { map {$_ => undef} (0 .. 7) },      # a
             1 => { map {$_ => undef} (1, 2, 3, 7) },  # b
             2 => { map {$_ => undef} (   2, 3, 7) },  # c
             3 => { 3 => undef },                      # d
             4 => { map {$_ => undef} (0 .. 7) },      # a1
             5 => { map {$_ => undef} (0 .. 7) },      # a2
             6 => { map {$_ => undef} (0 .. 7) },      # a3
             7 => { map {$_ => undef} (   2, 3, 7) }   # c1
            },
            'matrix()');
}


#==================================================================================================
done_testing();
