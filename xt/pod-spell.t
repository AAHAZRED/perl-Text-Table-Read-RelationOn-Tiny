use strict;
use warnings;

use Test::More;
use Test::Spelling;
use Pod::Wordlist;

set_spell_cmd('ispell -l');
add_stopwords(<DATA>);
all_pod_files_spelling_ok( qw( bin lib ) );


__DATA__

Hazred
subarray
subhash
subhashes
