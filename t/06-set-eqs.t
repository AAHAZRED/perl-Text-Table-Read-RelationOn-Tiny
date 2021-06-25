use 5.010_001;
use strict;
use warnings;

use Test::More;

use Text::Table::Read::RelationOn::Tiny;

#use constant RELATION_ON => "Text::Table::Read::RelationOn::Tiny"; # to make calls shorter.

{
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

  my $obj = Text::Table::Read::RelationOn::Tiny->new(set => \@set_elems,
                                                     eqs => [['that'], ['empty']]);

  ok($obj->prespec, "prespec() returns true");

  is_deeply($obj->elems,      \@set_elems,    "elems()");
  is_deeply($obj->elem_ids,   \%expected_ids, "elem_ids()");
  {
    note("Same order of elements");
    my $input = <<'EOT';

      | x\\y    | this | that | foo bar | empty |
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
    is_deeply([$obj->get(src => $input)],
              $expected,
              'Return values of get(STRING) in list context'
             );

    is($input, $input_bak, "Input string not changed");

    is_deeply($obj->elems,      \@set_elems,    "elems() unchanged");
    is_deeply($obj->elem_ids,   \%expected_ids, "elem_ids() unchanged");
    ok($obj->prespec, "prespec() still returns true");
  }
}


{
  my @set_elems = ( qw(a a1 a2 a3 b c c1 d) );
  my $elem_ids_expected = {'a'  => 0,
                           'a1' => 1,
                           'a2' => 2,
                           'a3' => 3,
                           'b'  => 4,
                           'c'  => 5,
                           'c1' => 6,
                           'd'  => 7
                          };
  my $tab_elems_expected = {a => 0,
                            b => 4,
                            c => 5,
                            d => 7
                           };
  my $obj = Text::Table::Read::RelationOn::Tiny->new(set => \@set_elems,
                                                     eqs => [[qw(a a1 a2 a3)],
                                                             [qw(c c1)]]);
  ok($obj->prespec, "prespec() returns true");
  is_deeply($obj->elems, \@set_elems, 'elems()');
  is_deeply($obj->elem_ids, $elem_ids_expected, 'elem_ids()');
  is_deeply($obj->tab_elems, $tab_elems_expected, 'tab_elems()');


  my $input = <<'EOT';
      |     | a | b | c | d |
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

  $obj->get(src => $input);

  is_deeply($obj->elem_ids, $elem_ids_expected, 'elem_ids() not changed');
  is_deeply($obj->tab_elems, $tab_elems_expected, 'tab_elems() not changed');

  is_deeply($obj->matrix, {
                           0 => {
                                 0 => undef,
                                 4 => undef,
                                 5 => undef,
                                 7 => undef
                                },
                           4 => {
                                 4 => undef,
                                 5 => undef,
                                 7 => undef
                                  },
                           5 => {
                                 5 => undef,
                                 7 => undef
                                  },
                           7 => {
                                 7 => undef
                                }
                          },
            'matrix'
           );

  note("allow_subset");
  $obj->get(src => ["|  *  | a |",
                    "| a   | X |"
                   ],
            allow_subset => 1
           );

  is_deeply($obj->elem_ids, $elem_ids_expected, 'elem_ids() not changed');
  is_deeply($obj->tab_elems, $tab_elems_expected, 'tab_elems() not changed');
  is_deeply($obj->matrix, {0 => {0 => undef}}, 'matrix()');
}




#==================================================================================================
done_testing();

