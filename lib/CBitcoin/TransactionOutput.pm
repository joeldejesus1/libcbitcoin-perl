package CBitcoin::TransactionOutput;

use 5.014002;
use strict;
use warnings;

=head1 NAME

CBitcoin::TransactionOutput - The great new CBitcoin::TransactionOutput!

=head1 VERSION

Version 0.01

=cut

use CBitcoin::Script;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::TransactionOutput::VERSION = '0.2';

DynaLoader::bootstrap CBitcoin::TransactionOutput $CBitcoin::TransactionOutput::VERSION;

@CBitcoin::TransactionOutput::EXPORT = ();
@CBitcoin::TransactionOutput::EXPORT_OK = ();


=item dl_load_flags

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
		# check if we can set up script and value to make sure that the data is valid
		$this->script;
		$this->value;
	}
	elsif(
		defined $x->{'value'} && $x->{'value'} =~ m/^[0-9]+$/
		&& defined $x->{'script'} 
	){
		# call this function to validate the data, and get serialized data back
		# this is a C function
		$this->{'data'} = create_txoutput_obj($x->{'script'},$x->{'value'});
	}
	else{
		die "no arguments to create Transaction::Output";
	}
		
	return $this;
}

=item serialized_data

---++ serialized_data

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
	return get_script_from_obj($this->{'data'});
}

=item type_of_script

---++ type_of_script

=cut

sub type_of_script {
	my $this = shift;
	return CBitcoin::Script::whatTypeOfScript( $this->script );
}

=item value

---++ value

=cut

sub value {
	my $this = shift;
	# this is a C function
	return get_value_from_obj($this->{'data'});
}

=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-transactionoutput at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::TransactionOutput


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

1; # End of CBitcoin::TransactionOutput
