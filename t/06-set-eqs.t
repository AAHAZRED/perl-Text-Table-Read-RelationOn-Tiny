use 5.010_001;
use strict;
use warnings;

use Test::More;

use Text::Table::Read::RelationOn::Tiny;

#use constant RELATION_ON => "Text::Table::Read::RelationOn::Tiny"; # to make calls shorter.

ok(1);

my $input = <<'EOT';

| x\y     | this |
|---------+------+
| that    |   X  |
|---------+------+
EOT
#Don't append a semicolon to the line above!

my $obj = Text::Table::Read::RelationOn::Tiny->new();

$obj->get(src => $input, allow_subset => 1);


note explain $obj;

#==================================================================================================
done_testing();
