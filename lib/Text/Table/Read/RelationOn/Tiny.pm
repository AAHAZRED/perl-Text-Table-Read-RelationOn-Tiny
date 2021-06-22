package Text::Table::Read::RelationOn::Tiny;

use 5.010_001;
use strict;
use warnings;
use autodie;

use Carp qw(confess);

# The following must be on the same line to ensure that $VERSION is read
# correctly by PAUSE and installer tools. See docu of 'version'.
use version 0.77; our $VERSION = version->declare("v2.0.0");


sub new {
  my $class = shift;
  $class = ref($class) if ref($class);
  my %arguments = @_;
  my $inc   = delete $arguments{inc}   // "X";
  my $noinc = delete $arguments{noinc} // "";
  my $set   = delete $arguments{set};
  my $eqs   = delete $arguments{eqs};
  confess(join(", ", sort(keys(%arguments))) . ": unexpected argument")
    if %arguments;
  confess("inc: must be a scalar")           if ref($inc);
  confess("noinc: must be a scalar")         if ref($noinc);
  confess("inc and noinc must be different") if $inc eq $noinc;
  my $self = {inc    => $inc,
              noinc  => $noinc,
             };
  if (ref($set) eq 'ARRAY') {
    my @elems;                         # elems
    my %tabElems;                      # elmes to be used in table --> indes in @elems
    my %eqIds;                         # idx => array of equivalent idxes
    my %ids;                           # indices in basic elems
    my @eqs_tmp;

    for (my $i = 0; $i < @$set; ++$i) {
      my $entry = $set->[$i];
      confess("set: entry $i: invalid") if !defined($entry);
      if (ref($entry)) {
        confess("set: entry $i: invalid") if ref($entry) ne 'ARRAY';
        confess("set: array not allowed if eqs is specified") if $eqs;
        confess("set: entry $i: array entry must not be empty") if !@{$entry};
        my $entry_0 = $entry->[0];
        confess("set: subentry must be a defined scalar") if ref($entry_0) || !defined($entry_0);
        push(@elems, $entry_0);
        $ids{$entry_0} = $tabElems{$entry_0} = $#elems;
        for (my $j = 1; $j < @$entry; ++$j) {
          my $entry_j = $entry->[$j];
          confess("set: '$entry_j': duplicate element") if exists($ids{$entry_j});
          confess("set: subentry must be a defined scalar") if ref($entry_j) || !defined($entry_j);
          push(@elems, $entry_j);
          $ids{$entry_j} = $#elems;
        }
        push(@eqs_tmp, $entry) if @$entry > 1;
      } else {
        confess("set: '$entry': duplicate entry") if exists($ids{$entry});
        push(@elems, $entry);
        $ids{$entry} = $tabElems{$entry} = $#elems;
      }
    }
    confess("Internal error") if (defined($eqs) && @eqs_tmp); # Should never happen.
    $eqs = \@eqs_tmp if @eqs_tmp;
    if (defined($eqs)) {
      confess("eqs: must be an array ref") if ref($eqs) ne 'ARRAY';
      foreach my $eqArray (@{$eqs}) {
        confess("eqs: each entry must be an array ref") if ref($eqArray) ne 'ARRAY';
        next if !@{$eqArray};
        foreach my $entry (@{$eqArray}) {
          confess("eqs: subentry contains a non-scalar") if ref($entry);
          confess("eqs: subentry undefined")             if !defined($entry);
        }
        next if @{$eqArray} == 1;
        my @tmp = @{$eqArray};
        my @eqArray;
        $eqIds{$tabElems{shift(@tmp)}} = \@eqArray;
        foreach my $e (@tmp) {
          push(@eqArray, delete $tabElems{$e});
        }
      }
    }
    @{$self}{qw(elems elem_ids tab_elems eq_ids)} = (\@elems, \%ids, \%tabElems, \%eqIds);
  } elsif (defined($set)) {
    confess("set: must be an array reference");
  } else {
    confess("eqs: not allowed without argument 'set'") if defined($eqs);
  }
  return bless($self, $class);
}


# just a function, not a method.
sub _parse_header_f {
  my $header = shift;
  $header =~ s/^\s*\|.*?\|\s*// or confess("'$header': Wrong header format");
  my @elem_array = $header eq "|" ? ('') : split(/\s*\|\s*/, $header);
  return ([], {}) if $header eq "";
  my $index = 0;
  my %elem_ids;
  foreach my $name (@elem_array) {
    confess("'$name': duplicate name in header") if exists($elem_ids{$name});
    $elem_ids{$name} = $index++;
  }
  return (\@elem_array, \%elem_ids);
}


my $_parse_row = sub {
  my $self = shift;
  my $row = shift;
  my ($inc, $noinc) = @{$self}{qw(inc noinc)};
  $row =~ s/^\|\s*([^|]*?)\s*\|\s*// or confess("Wrong row format: '$row'");
  my $rowElem = $1;
  my @rowContents;
  foreach my $entry (split(/\s*\|\s*/, $row, -1)) {
    if ($entry eq $inc) {
      push(@rowContents, 1);
    } elsif ($entry eq $noinc) {
      push(@rowContents, "");
    } else {
      confess("'$entry': unexpected entry");
    }
  }
  return ($rowElem, \@rowContents);
};


my $_parse_table = sub {
  my $self = shift;
  my $lines = shift;
  my $index = 0;
  for (; $index < @$lines; ++$index) { # skip heading empty lines
    last if $lines->[$index] =~ /\S/;
  }
  if ($index == @$lines) {
    @{$self}{qw(matrix elems elem_ids tab_elems eq_ids)} = ({}, {}, (), (), ());
    return $self->{matrix};
  }
  my ($h_elems, $h_ids) = _parse_header_f($lines->[$index++]);
  my %rows;
  for (; $index < @$lines; ++$index) {
    (my $line = $lines->[$index]) =~ s/^\s+//;
    last if $line eq q{};
    next if substr($line, 0, 2) eq "|-";
    $line =~ s/\s+$//;
    my ($rowElem, $rowContent) = $self->$_parse_row($line);
    confess("'$rowElem': duplicate element in first column") if exists($rows{$rowElem});
    $rows{$rowElem} = $rowContent;
  }
  my $elem_ids     = $self->{elem_ids};
  my $allow_subset = $self->{allow_subset};
  if ($elem_ids) {
    foreach my $elem (keys(%{$h_ids})) {
      confess("'$elem': unknown element in table") if !exists($elem_ids->{$elem});
    }
    foreach my $elem (keys(%rows)) {
      confess("'$elem': unknown element in table") if !exists($elem_ids->{$elem});
    }
    if (!$allow_subset) {
      foreach my $elem (keys(%{$elem_ids})) {
        confess("'$elem': element missing in table (header)") if !exists($h_ids->{$elem});
        confess("'$elem': element missing in table (row)"   ) if !exists($rows{$elem});
      }
    }
  } else {
    if ($allow_subset) {
      foreach my $elem (keys(%rows)) {
        if (!exists($h_ids->{$elem})) {
          $h_ids->{$elem} = @{$h_elems};
          push(@{$h_elems}, $elem);
        }
      }
    } else {
      confess("Number of elements in header does not match")
        if keys(%{$h_ids}) != keys(%rows);
      foreach my $elem (keys(%{$h_ids})) {
        confess("'$elem': row missing for element") if !exists($rows{$elem});
      }
      foreach my $elem (keys(%rows)) {
        confess("'$elem': column missing for element") if !exists($h_ids->{$elem});
      }
    }
    my %tmp = %{$h_ids};
    @{$self}{qw(elems elem_ids tab_elems eq_ids)} = ($h_elems, $h_ids, \%tmp, {});
    $elem_ids = $h_ids;
  }
  my $elems = $self->{elems};
  my %matrix;
  while (my ($rowElem, $rowContents) = each(%rows)) {
    my $matrixRow  = {};
    for (my $i = 0; $i < @{$rowContents}; $i++) {
      $matrixRow->{$elem_ids->{$h_elems->[$i]}} = undef if $rowContents->[$i];
    }
    $matrix{$elem_ids->{$rowElem}} = $matrixRow if %{$matrixRow};
  }
  return $self->{matrix} = \%matrix;
};


sub get {
  my $self = shift;
  confess("Missing argument")        if !@_;
  confess("Odd number of arguments") if @_ % 2;
  my ($src, $allow_subset) = @{{@_}}{qw(src allow_subset)};
  my $inputArray;
  if (ref($src)) {
    confess("Invalid value argument for 'src'") if ref($src) ne 'ARRAY';
    foreach my $e (@{$src}) {
      confess("src: each entry must be a defined scalar") if (ref($e) || !defined($e));
    }
    $inputArray = $src;
  } elsif ($src !~ /\n/) {
    open(my $h, '<', $src);
    $inputArray = [<$h>];
    close($h);
  } else {
    $inputArray = [split(/\n/, $src)];
  }
  $self->$_parse_table->($inputArray);
  return wantarray ? @{$self}{qw(matrix elems elem_ids)} : $self;
}




sub inc         {confess("Unexpected argument(s)") if @_ > 1; $_[0]->{inc};}
sub noinc       {confess("Unexpected argument(s)") if @_ > 1; $_[0]->{noinc};}
sub elems       {confess("Unexpected argument(s)") if @_ > 1; $_[0]->{elems};}
sub elem_ids    {confess("Unexpected argument(s)") if @_ > 1; $_[0]->{elem_ids};}
sub matrix      {confess("Unexpected argument(s)") if @_ > 1; $_[0]->{matrix};}


sub bless_matrix {
  return bless($_[0]->{matrix}, "Text::Table::Read::RelationOn::Tiny::_Relation_Matrix");
}


{
  package Text::Table::Read::RelationOn::Tiny::_Relation_Matrix;

  sub related { return exists($_[0]->{$_[1]}) && exists($_[0]->{$_[1]}->{$_[2]}); }
}


1; # End of Text::Table::Read::RelationOn::Tiny



__END__


=pod


=head1 NAME

Text::Table::Read::RelationOn::Tiny - Read binary "relation on (over) a set" from a text table.



=head1 VERSION

Version v2.0.0


=head1 SYNOPSIS

    use Text::Table::Read::RelationOn::Tiny;

    my $obj = Text::Table::Read::RelationOn::Tiny
    my ($matrix, $elems, $ids) = $obj->get('my-table.txt');


=head1 DESCRIPTION

Minimum version of perl required to use this module: C<v5.10.1>.

This module implements a class that reads a binary I<relation on a set>
(I<homogeneous relation>, see
L<https://en.wikipedia.org/wiki/Binary_relation#Homogeneous_relation>) from a
text table.

The table format must look like this:


   | x\y     | this | that | foo bar |
   |---------+------+------+---------+
   | this    | X    |      | X       |
   |---------+------+------+---------+
   | that    |      |      | X       |
   |---------+------+------+---------+
   | foo bar |      | X    |         |
   |---------+------+------+---------+

=over

=item *

Tables are read by method C<get>, see below.

=item *

Only two different table entries are possible, these are C<X> and the empty
string (this is default and can be changed, see description of C<new>).

=item *

The entry in the table's upper left corner is simply ignored and may be empty,
but you cannot ommit the upper left C<|> character.

=item *

The hotizontal rules are optional.

=item *

There is not something like a format check for the horizontal rules. Any line
starting with C<|-> is simply ignored, regardless of the other subsequent
characters, if any.

=item *

The entries (names) in the header line are the set's element names. One of
these names may be the empty string.


=item *

The names of the columns (header line) and the rows (first entry of each row)
need to be the same and they must be unique, but they don't have to appear in the
same order.

=item *

Spaces at the beginning of a line are ignored.

=back


=head2 METHODS

=head3 new

The constructor take the following optional named scalar arguments:

=over

=item C<inc>

A string. Table entry that flags that the corresponding elements are
related. Default is "X".

=item C<noinc>

A string. Table entry that flags that the corresponding elements are B<not>
related. Default is the empty set.

=item C<set>

If specified, then this must be an array of unique strings specifying the
elements of the set for your relation. When the constructor was called with
this argument, then method C<elems> will return a reference to a copy of it,
and C<elem_ids> will return a hash mapping each element to its array index
(otherwise both methods would return C<undef> before the first call to
C<get>).

Method C<get> will check if the elements in the input table are the same as
those specified in the array. Furthermore, the indices in C<matrix> will
always refere to the indices in the C<set> array, and C<elems> and C<elem_ids>
will always return the same, regardless of the order of rows and columns in
the input table.

It may happen that there are elements that are identical with respect to the
relation and you do not want to write duplicate rows and columns in your
table. To cover such a case, it is allowed that entries of C<set> are array
references again.

Example:

  [[qw(a a1 a2 a3)], 'b', [qw(c c1)], 'd']

In this case, the elements you write in your table are C<a>, C<b>, C<c>, and
C<d> (in case of a subarray always the first element is taken). Method C<get>
will add corresponding rows and columns for C<a1>, C<a2>, C<a3>, and C<c1> to
the incidence matrix. Method C<elems> will return this (note the order of the
elements):

  [a b c d a1 a2 a3 c1]

Method C<elem_ids> will return:

  { a => 0, a1 => 0, a2 => 0, a3 => 0,
    b => 1,
    c => 2, c1 => 2,
    d => 3
  }


=back

If you specify both arguments, then their vaules must be different.


=head3 get

The method reads and parses a table. It takes exactly one argument which may
be either a file name, an array reference or a string containing newline
characters.

=over

=item C<src>

Mandatory. The source from which the table is to be read. May be either a file
name, an array reference or a string containing newline characters.

=item C<allow_subset>

Optional. Take a boolean value. If I<true>, then rows and columns

=back


=over

=item Argument is an array reference

The method treats the array entries as the rows of the table.

=item Argument is a string containing newlines

The method treats the argument as a string representation of the table and
parses it.

=item Argument is a string B<not> containing newlines

The method treats the argument as a file name and tries to read the table from
that file.

=back

Note that the method will stop parsing if it recognizes a line containing not
any non-white character and will ignore any subsequent lines.

B<Parsing>

When parsing a table, the method first creates an array of set element names
from the table's header line (you can obtain this array from the returned list
or from method C<elems>).

It then creates a hash whose keys are the element names and each value is the
index in the element array just mentioned (you can obtain this hash from
the returned list or from method C<elem_ids>).

Finally, it creates a hash of hashes representing the relation (incidence
matrix): each key is an integer which is an index in the element array created
before. Each corresponding value is again a hash where the keys are the array
indices of the elements being in relation; the values do not matter and are
always C<undef>. This hash will never contain empty subhashes. (you can obtain
this hash from the returned list or from method C<matrix>).

B<Example>

This table:

    | x\y   | norel |      | foo | bar |
    |-------+-------+------+-----+-----|
    | norel |       |      |     |     |
    |-------+-------+------+-----+-----|
    |       |       | X    | X   |     |
    |-------+-------+------+-----+-----|
    | foo   |       |      |     | X   |
    |-------+-------+------+-----+-----|
    | bar   |       |      | X   |     |
    |-------+-------+------+-----+-----|

will result in this array:

  ('norel', '', 'foo', 'bar')

this hash:

  ('norel' => 0, '' => 1, 'foo' => 2, 'bar' => 3)

and in this hash representing the incidence matrix:

  1 => {
           1 => undef,
           2 => undef
         },
  3 => {
           2 => undef
         },
  2 => {
           3 => undef
         }

Note that element C<norel> (id 0), which is not in any relation, does not
appear in this hash (it would be C<< 0 => {} >> but as said, empty subhashes
are not contained).


B<Return value>:

In scalar context, the method returns simply the object.

In list context, the method returns a list containing three references
corresponding to the accessor methods C<matrix>, C<elems> and C<elem_ids>: the
hash representing the incidence matrix, the element array and the element
index (id) hash. Thus, wirting:

  my ($matrix, $elems, $elem_ids) = $obj->get($my_input);

is the same as writing

   $obj->get($my_input);
   my $matrix   = $obj->matrix;
   my $elems    = $obj->elems;
   my $elem_ids = $obj->elem_ids;

However, the first variant is shorter and needs only one method call.


=head3 C<inc>

Returns the current value of C<inc>. See description of C<new>.


=head3 C<noinc>

Returns the current value of C<noinc>. See description of C<new>.


=head3 C<matrix>

Returns the incidence matrix (reference to a hash of hashes) produced by the
most recent call of C<get>, or C<undef> if you did not yet call C<get> for the
current object. See description of C<get>.


=head3 C<elems>

Returns a reference to the array of elements (names from the table's header
line), or C<undef> if you did neither call C<get> for the current object nor
specified option C<set> when calling the constructor. See description of
C<get> and C<new>.


=head3 C<elem_ids>

Returns a reference to a hash mapping elements to ids (indices in array
returned by C<elems>), or C<undef> if you did neither call C<get> for the
current object nor specified argument C<set> when calling the constructor. If
you used constructor argument C<set> to specify duplicates, then the
duplicates are mapped to the same index (especially each index is smaller than
the return value of XXXXXXXXXXXXXX). See description of C<get> and C<new>.


=head3 C<bless_matrix>

Blesses C<matrix> with
C<Text::Table::Read::RelationOn::Tiny::_Relation_Matrix> and for convenience
also returns it. Then you can use C<matrix> as an object having exactly one
method named C<related>. This method again takes two arguments (integers) and
check if these are related with respect to the incidence C<matrix>. Note that
c<related> does not do any parameter check.

Example:

  $rel_obj->bless_matrix;
  my $matrix = $rel_obj->matrix;
  if ($matrix->related(2, 5)) {
    # ...
  }

or shorter:

  my $matrix = $rel_obj->bless_matrix;
  if ($matrix->related(2, 5)) {
    # ...
  }


=head1 AUTHOR

Abdul al Hazred, C<< <451 at gmx.eu> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-text-table-read-relationon-tiny at rt.cpan.org>, or through the web
interface at
L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-Table-Read-RelationOn-Tiny>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::Table::Read::RelationOn::Tiny


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-Table-Read-RelationOn-Tiny>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Text-Table-Read-RelationOn-Tiny>

=item * Search CPAN

L<https://metacpan.org/release/Text-Table-Read-RelationOn-Tiny>

=item * GitHub Repository

L<https://github.com/AAHAZRED/perl-Text-Table-Read-RelationOn-Tiny>


=back



=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2021 by Abdul al Hazred.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut
