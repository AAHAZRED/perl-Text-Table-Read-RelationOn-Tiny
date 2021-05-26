package Text::Table::Read::RelationOn::Tiny;

use 5.010_001;
use strict;
use warnings;
use autodie;

use Carp qw(confess);

# The following must be on the same line to ensure that $VERSION is read
# correctly by PAUSE and installer tools. See docu of 'version'.
use version 0.77; our $VERSION = version->declare("v1.0.2");


sub new {
  my $class = shift;
  $class = ref($class) if ref($class);
  my %arguments = @_;
  my $inc   = delete $arguments{inc}   // "X";
  my $noinc = delete $arguments{noinc} // "";
  my $set   = delete $arguments{set};
  confess(join(", ", sort(keys(%arguments))) . ": unexpected argument")
    if %arguments;
  confess("inc: must be a scalar")           if ref($inc);
  confess("noinc: must be a scalar")         if ref($noinc);
  confess("inc and noinc must be different") if $inc eq $noinc;
  my $self = {inc    => $inc,
              noinc  => $noinc,
             };
  if (ref($set) eq 'ARRAY') {
    my %ids;
    my @set_copy = @{$set};
    for (my $i = 0; $i < @set_copy; ++$i) {
      my $entry = $set_copy[$i];
      confess("set: entry $i: invalid") if !defined($entry) || ref($entry);
      confess("set: '$entry': duplicate entry") if exists($ids{$entry});
      $ids{$entry} = $i;
    }
    @{$self}{qw(prespec elems elem_ids)} = (1, \@set_copy, \%ids);
  } elsif (defined($set)) {
    confess("set: must be an array reference");
  } else {
    $self->{prespec} = "";
  }
  return bless($self, $class);
}


sub get {
  my $self = shift;
  confess("Wrong number of arguments") if @_ != 1;
  my @lines;
  if (ref($_[0])) {
    confess("Invalid argument") if ref($_[0]) ne 'ARRAY';
    @lines = @{$_[0]};
  } elsif ($_[0] !~ /\n/) {
    open(my $h, '<', $_[0]);
    @lines = <$h>;
    close($h);
  } else {
    @lines = split(/\n/, $_[0]);
  }

  my ($elem_array, $elem_ids) = _get_elems_from_header(\@lines);
  my $elem_ids_o;
  if ($self->{prespec}) {
    confess("Wrong number of elements in table") if @{$elem_array} != @{$self->{elems}};
    my $predef_elem_ids = $self->{elem_ids};
    foreach my $elem (@{$elem_array}) {
      confess("'$elem': unknown element in table") if !exists($predef_elem_ids->{$elem});
    }
    $elem_ids_o = $predef_elem_ids;
  } else {
    @{$self}{qw(elems elem_ids)} = ($elem_array, $elem_ids);
    $elem_ids_o = $elem_ids;
  }
  my %remaining_elements = map {$_ => undef} @{$elem_array};
  my ($inc, $noinc) = @{$self}{qw(inc noinc)};
  my %matrix;
  my %seen;
  foreach my $line (@lines) {
    $line =~ s/^\s+//;
    last if $line eq "";
    next if substr($line, 0, 2) eq "|-";
    $line =~ s/^\|\s*([^|]*?)\s*\|\s*// or confess("Wrong row format: '$line'");
    my $element = $1;
    confess("'$element': duplicate element") if exists($seen{$element});
    confess("'$element': not in header") if !exists($remaining_elements{$element});
    delete $remaining_elements{$element};
    $seen{$element} = undef;
    $line =~ s/\s*\|\s*$//;
    my %new_row;
    my $index = 0;
    foreach my $entry (split(/\s*\|\s*/, $line, -1)) {
      if ($entry eq $inc) {
        $new_row{$elem_ids_o->{$elem_array->[$index]}} = undef;
      } elsif ($entry ne $noinc) {
        confess("'$entry': unexpected entry");
      }
      $index++;
    }
    $matrix{$elem_ids_o->{$element}} = \%new_row if %new_row;
  }
  confess(join(', ', map("'$_'", sort(keys(%remaining_elements)))) . ": no rows for this elements")
    if %remaining_elements;

  $self->{matrix}   = \%matrix;
  return wantarray ? @{$self}{qw(matrix elems elem_ids)} : $self;
}

sub inc      {confess("Unexpected arguments") if @_ > 1; $_[0]->{inc};}
sub noinc    {confess("Unexpected arguments") if @_ > 1; $_[0]->{noinc};}
sub matrix   {confess("Unexpected arguments") if @_ > 1; $_[0]->{matrix};}
sub elems    {confess("Unexpected arguments") if @_ > 1; $_[0]->{elems};}
sub elem_ids {confess("Unexpected arguments") if @_ > 1; $_[0]->{elem_ids};}
sub prespec  {confess("Unexpected arguments") if @_ > 1; $_[0]->{prespec};}


sub _get_elems_from_header {
  my $lines = shift;
  my $header;
  while (defined($header = shift(@{$lines})) and $header !~ /\S/) { 1; }
  return ([], {}) if !defined($header);
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



1; # End of Text::Table::Read::RelationOn::Tiny



__END__


=pod


=head1 NAME

Text::Table::Read::RelationOn::Tiny - Read binary "relation on (over) a set" from a text table.



=head1 VERSION

Version v1.0.2


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


=back

If you specify both arguments, then their vaules must be different.


=head3 get

The method reads and parses a table. It takes exactly one argument which may
be either a file name, an array reference or a string containing newline
characters.

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

Returns a reference to the hash element ids (indices in array returned by
C<elems>), or C<undef> if you did neither call C<get> for the current object
nor specified option C<set> when calling the constructor. See description of
C<get> and C<new>.


=head3 C<prespec>

Returns 1 (true) if you specified argument C<set> when calling the
constructor, otherwise it returns an empty string (false).


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
