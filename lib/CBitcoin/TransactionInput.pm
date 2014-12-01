package CBitcoin::TransactionInput;

use 5.014002;
use strict;
use warnings;
use CBitcoin::Script;

=head1 NAME

CBitcoin::TransactionInput - The great new CBitcoin::TransactionInput!

=head1 VERSION

Version 0.01

=cut

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::TransactionInput::VERSION = '0.01';

DynaLoader::bootstrap CBitcoin::TransactionInput $CBitcoin::TransactionInput::VERSION;

@CBitcoin::TransactionInput::EXPORT = ();
@CBitcoin::TransactionInput::EXPORT_OK = ();


=item dl_load_flags

Don't worry about this.

=cut


sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

=item new

---++ new()

=cut


sub new {
	use bigint;
	my $package = shift;
	my $this = bless({}, $package);

	my $x = shift;
	unless(ref($x) eq 'HASH'){
		return $this;
	}
	if(defined $x->{'data'} && $x->{'data'} =~ m/^([0-9a-zA-Z]+)$/){
		# we have a tx input which is serialized
		$this->{'data'} = $x->{'data'};
	
	}
	elsif(
		defined $x->{'prevOutHash'} && $x->{'prevOutHash'} =~ m/^([0-9a-fA-F]+)$/
		&& defined $x->{'prevOutIndex'} && $x->{'prevOutIndex'} =~ m/[0-9]+/
		&& defined $x->{'script'}
	){
		my $sequence = hex('0xFFFFFFFF') unless defined $x->{'sequence'};
		# call this function to validate the data, and get serialized data back
		#char* create_txinput_obj(char* scriptstring, int sequenceInt, char* prevOutHashString, int prevOutIndexInt){
		$this->{'data'} = create_txinput_obj(
			$x->{'script'}
			,$sequence
			,$x->{'prevOutHash'}
			,$x->{'prevOutIndex'}
		);
		$this->script;
		$this->prevOutHash;
		$this->prevOutIndex;
	}
	else{
		die "no arguments to create Transaction::Input";
	}

	return $this;
}

=item serialized_data

---++ serialized_data()

=cut


sub serialized_data {
	my $this = shift;
	return $this->{'data'};
}

=item script

---++ script

=cut

sub script {
	my $this = shift;
	# this is a C function
	return get_script_from_obj($this->{'data'});
}

=item type_of_script

---++ type_of_script

=cut

sub type_of_script {
	my $this = shift;
	return CBitcoin::Script::whatTypeOfScript( $this->script );
}

=item prevOutHash

---++ prevOutHash()

=cut

sub prevOutHash {
	#use bigint;
	my $this = shift;
	# this is a C function
	get_prevOutHash_from_obj($this->{'data'});
}

=item prevOutIndex

---++ prevOutIndex()

=cut

sub prevOutIndex {
	use bigint;
	my $this = shift;
	return get_prevOutIndex_from_obj($this->{'data'});
}

=item sequence

---++ sequence

=cut

sub sequence {
	use bigint;
	my $this = shift;
	return get_sequence_from_obj($this->{'data'});
}

=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-transactioninput at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::TransactionInput


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=libperl-cbitcoin>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/libperl-cbitcoin>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/libperl-cbitcoin>

=item * Search CPAN

L<http://search.cpan.org/dist/libperl-cbitcoin/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin::TransactionInput
