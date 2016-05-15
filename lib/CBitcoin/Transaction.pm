package CBitcoin::Transaction;

use 5.014002;
use strict;
use warnings;

=head1 NAME

CBitcoin::Transaction - The great new CBitcoin::Transaction!

=head1 VERSION

Version 0.01

=cut

use bigint;
use CBitcoin::Script;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Utilities;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Transaction::VERSION = '0.1';

DynaLoader::bootstrap CBitcoin::Transaction $CBitcoin::Transaction::VERSION;

@CBitcoin::Transaction::EXPORT = ();
@CBitcoin::Transaction::EXPORT_OK = ();

=item dl_load_flags

Nothing to see here.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking



=item new

---++ new($options)

<verbatim>$options = {
	'inputs' => \@txinputs, 'outputs' => \@txoutputs
};</verbatim>


=cut

sub new {
	my $package = shift;
	my $this = bless({}, $package);
	my $options = shift;


	if(
		defined $options && ref($options) eq 'HASH'
		&& defined $options->{'inputs'} && ref($options->{'inputs'}) eq 'ARRAY'
		&& defined $options->{'outputs'} && ref($options->{'outputs'}) eq 'ARRAY'
	){
		my ($n,$m,$i,$j);
		
		$j = 'inputs';
		$n = scalar(@{$options->{$j}});
		for($i=0;$i<$n;$i++){
			die "bad type in $j with ref=".ref($options->{$j}->[$i]) 
				unless ref($options->{$j}->[$i]) eq 'CBitcoin::TransactionInput';
			$this->{$j}->[$i] = $options->{$j}->[$i];
		}

		$j = 'outputs';
		$n = scalar(@{$options->{$j}});
		for($i=0;$i<$n;$i++){
			die "bad type in $j with ref=".ref($options->{$j}->[$i]) 
				unless ref($options->{$j}->[$i]) eq 'CBitcoin::TransactionOutput';
			$this->{$j}->[$i] = $options->{$j}->[$i];
		}
			
	}
	else{
		die "bad inputs";
	}
	
	
	return $this;
}

=pod

---++ deserialize($serialized_tx)


Get a hash back, not a blessed object.

version
inputs => [..]
outputs => [..]
locktime

input = {prevHash, prevIndex, script, sequence}
output = {value, script}

=cut

sub deserialize{
	my ($package,$data) = @_;
	
	

#	return $tx;
}




=item lockTime

---++ lockTime

=cut

sub lockTime {
	return shift->{'lockTime'};
}

=item version

---++ version

=cut

sub version {
	return shift->{'version'};
}

=item hash

---++ hash

=cut

sub hash {
	return shift->{'hash'};
}


# signatures....

=item sign_single_input

---+++ sign_single_input($index,$cbhdkey)

Sign the ith ($index) output with the private key corresponding to the inputs.  The index starts from 0!!!!!

=cut

sub sign_single_input {
	my $this = shift;
	
}




=pod

---++ addRedeemScript($input_index,$script)

This adds the redeem script to the end of the stack. (scriptSig in picocoin parlance)

=cut

sub add_redeem_script {
	my $this = shift;
	
}


=item numOfInputs

---++ numOfInputs

=cut

sub numOfInputs {
	return scalar(@{shift->{'inputs'}});
}

=item input

---++ input($index)

=cut

sub input {
	return shift->{'inputs'}->[shift];
}

=item numOfOutputs

---++ numOfOutputs()

=cut

sub numOfOutputs {
	return scalar(@{shift->{'outputs'}});
}

=pod

---++ output($index)

=cut

sub output {
	return shift->{'output'}->[shift];
}

=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-transaction at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::Transaction


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

1; # End of CBitcoin::Transaction
