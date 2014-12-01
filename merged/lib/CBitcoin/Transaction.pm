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

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Transaction::VERSION = '0.01';

DynaLoader::bootstrap CBitcoin::Transaction $CBitcoin::Transaction::VERSION;

@CBitcoin::Transaction::EXPORT = ();
@CBitcoin::Transaction::EXPORT_OK = ();

=item dl_load_flags

Nothing to see here.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking



=item new

---++ new()

=cut

sub new {
	use bigint;
	my $package = shift;
	my $this = bless({}, $package);
	$this->{'inputs'} = [];
	$this->{'outputs'} = [];
	my $x = shift;
	unless(ref($x) eq 'HASH'){
		return $this;
	}
	if(defined $x->{'data'} && $x->{'data'} =~ m/^([0-9a-zA-Z]+)$/){
		# we have a tx input which is serialized
		$this->{'data'} = $x->{'data'};
		# test to see if the data is valid
	}
	elsif(
		defined $x->{'inputs'} && ref($x->{'inputs'}) eq 'ARRAY'
		&& defined $x->{'outputs'} && ref($x->{'outputs'}) eq 'ARRAY'
	){
		# we have the data, let's get the serialized data
		$x->{'lockTime'} ||= 0;
		$x->{'version'} ||= 1;
		my @inputs;
		foreach my $i1 (@{$x->{'inputs'}}){
			#warn "Input:".$i1->serialized_data."\n";
			push(@inputs,$i1->serialized_data);
		}
		my @outputs;
		foreach my $i1 (@{$x->{'outputs'}}){
			#warn "Output:".$i1->serialized_data."\n";
			push(@outputs,$i1->serialized_data);
		}
		# char* create_tx_obj(int lockTime, int version, SV* inputs, SV* outputs, int numOfInputs, int numOfOutputs){
		$this->{'data'} = create_tx_obj(
			$x->{'lockTime'}
			,$x->{'version'}
			,\@inputs
			,\@outputs
			,scalar(@inputs)
			,scalar(@outputs)
		);
		# make sure the data is properly formatted
		$this->lockTime();
		$this->version();
	}
	else{
		die "no arguments to create transaction";
	}
	
	
	return $this;
}

=item serialized_data

---++ serialized_data

=cut

sub serialized_data {
	my $this = shift;
	my $newdata = shift;
	if(defined $newdata && $newdata =~ m/^([0-9a-zA-Z]+)$/){
		$this->{'data'} = $newdata;
		return $this->{'data'};
	}
	elsif(!(defined $newdata)){
		return $this->{'data'};
	}
	else{
		die "malformed serialized data";
	}

}

=item lockTime

---++ lockTime

=cut

sub lockTime {
	my $this = shift;
	# this is a C function
	return get_lockTime_from_obj($this->{'data'});
}

=item version

---++ version

=cut

sub version {
	my $this = shift;
	# this is a C function
	return get_version_from_obj($this->{'data'});
}

=item hash

---++ hash

=cut

sub hash {
	my $this = shift;
	return hash_of_tx($this->{'data'});	
}


# signatures....

=item sign_single_input

---+++ sign_single_input($index,$cbhdkey)

Sign the ith ($index) output with the private key corresponding to the inputs.  The index starts from 0!!!!!

=cut

sub sign_single_input {

	#use bigint;
	
	my $this = shift;
	my $OldData = $this->serialized_data();
	#die "not correct Transaction type" unless ref($this) eq 'CBitcoin::Transaction';
	my ($index,$keypair) = (shift,shift);
	unless($index =~ m/\d+/ && 0 <= $index && $index < $this->numOfInputs){
		die "index is not in the proper range ($index).\n";
	}
	unless($keypair->address =~ m/^[0-9a-zA-Z]+$/){
		die "keypair is not a CBitcoin::CBHD object.\n";
	}

	unless($this->serialized_data()){
		die "serialize the tx data first, before trying to sign prevOuts.\n";
	}
	
	# get the input
	my $prevOutInput = $this->input($index);
	
	# find out what type of script we are dealing with
	# 	p2sh, pubkey, keyhash, multisig
	#my $scripttype = CBitcoin::Script::whatTypeOfScript($prevOutInput->script() );
	my $script = $prevOutInput->script();
	#warn "My script:".$prevOutInput->script()."\n";
	my $data;

	if($script =~ m/OP_HASH160/){
		$data = CBitcoin::Transaction::sign_tx_pubkeyhash(
			$this->serialized_data()
			,$keypair->serialized_data()
			,$prevOutInput->script()
			,$index
			,'CB_SIGHASH_ALL'
		);
	}
	elsif($script =~ m/OP_CHECKMULTISIG/ || $script =~ m/OP_CHECKMULTISIGVERIFY/ ){
		# do multisig 
		$data = CBitcoin::Transaction::sign_tx_multisig(
			$this->serialized_data()
			,$keypair->serialized_data()
			,$prevOutInput->script()
			,$index
			,'CB_SIGHASH_ALL'
		);
	}
	else{
		die "unsupported script($script)";
	}
	# make sure that the new data contains something different
	die "signature failed" if $data eq $OldData;
	#warn "New Signature ($data)\n";
	return $this->serialized_data($data);	
}

=item numOfInputs

---++ numOfInputs

=cut

sub numOfInputs {
	my $this = shift;
	return get_numOfInputs($this->{'data'});	
}

=item input

---++ input($index)

=cut

sub input {
	my $this = shift;
	my $index = shift;
	unless($index =~ m/\d+/ && $index >= 0 && $index < $this->numOfInputs() ){
		die "index is not an integer or in the proper range\n";
	}
	# char* get_Input(char* serialized_dataString,int InputIndex)
	return CBitcoin::TransactionInput->new({'data' => get_Input($this->{'data'},$index) });
}

=item numOfOutputs

---++ numOfOutputs()

=cut

sub numOfOutputs {
	my $this = shift;
	return get_numOfOutputs($this->{'data'});
}

=item output

---++ output

=cut

sub output {
	my $this = shift;
	my $index = shift;
	unless($index =~ m/\d+/ && $index >= 0 && $index < $this->numOfOutputs() ){
		die "index is not an integer or in the proper range\n";
	}
	# char* get_Input(char* serialized_dataString,int InputIndex)
	return CBitcoin::TransactionOutput->new({'data' => get_Output($this->{'data'},$index) });
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
