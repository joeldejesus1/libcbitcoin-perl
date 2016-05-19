package CBitcoin::Transaction;

use 5.014002;
use strict;
use warnings;

use constant {
	SIGHASH_ALL => 0x00000001, # <--- this is the default
	SIGHASH_NONE => 0x00000002,
	SIGHASH_SINGLE => 0x00000003,
	SIGHASH_ANYONECANPAY => 0x00000080
};

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

our $default_version = 1;
our $default_locktime = 0;

=item new

---++ new($options)

<verbatim>$options = {
	'inputs' => \@txinputs, 'outputs' => \@txoutputs
};</verbatim>


=cut

sub new {
	my $package = shift;
	my $this = bless({
		'version' => $default_version
	}, $package);
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
	
	
	$this->{'lockTime'} = $default_locktime unless defined $this->{'lockTime'};
	$this->{'version'} = $default_version unless defined $this->{'version'};
	
	
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
	return shift->{'outputs'}->[shift];
}

=pod

---+ i/o

=cut

=pod

---++ serialize

4 	version 	int32_t 	Transaction data format version (note, this is signed)
1+ 	tx_in count 	var_int 	Number of Transaction inputs
41+ 	tx_in 	tx_in[] 	A list of 1 or more transaction inputs or sources for coins
1+ 	tx_out count 	var_int 	Number of Transaction outputs
9+ 	tx_out 	tx_out[] 	A list of 1 or more transaction outputs or destinations for coins 

=cut

sub serialize {
	my ($this) = @_;
	
	my $data = pack('l',$this->version);
	
	$data .= CBitcoin::Utilities::serialize_varint($this->numOfInputs);
	for(my $i=0;$i<$this->numOfInputs;$i++){
		$data .= $this->input($i)->serialize();
	}
	
	$data .= CBitcoin::Utilities::serialize_varint($this->numOfOutputs);
	for(my $i=0;$i<$this->numOfOutputs;$i++){
		$data .= $this->output($i)->serialize();
	}
	
	$data .= pack('L',$this->lockTime);
	
	return $data;
}


=pod

---++ validate($data)

=cut

sub validate{
	my ($this,$data) = @_;
	die "no data provided" unless defined $data && 0 < length($data);
	
	return picocoin_tx_validate($data);

}

=pod

---++ sign_single_input_p2pkh($key,$index)

https://en.bitcoin.it/wiki/OP_CHECKSIG - has the hash type explanantion
| SIGHASH_ALL | 0x00000001 |
| SIGHASH_NONE | 0x00000002 |
| SIGHASH_SINGLE | 0x00000003 |
| SIGHASH_ANYONECANPAY | 0x00000080 | 

=cut



sub sign_single_input_p2pkh {
	my ($this,$cbhdkey,$i) = @_;
	
	die "bad key" unless defined $cbhdkey && ref($cbhdkey) =~ m/CBHD/;
	
	my $xpriv = $cbhdkey->serialized_private();
	die "bad key" unless defined $xpriv && length($xpriv) == 78;
	
	die "bad index" unless defined $i && 0 <= $i && $i < $this->numOfInputs();
	
	# SV* fromPubKey_data, SV* txdata,int nIndex, int HashType
	my $script = CBitcoin::Script::serialize_script($this->input($i)->script());
	my $data = $this->serialize();
	
	return picocoin_tx_sign_p2pkh(
		$cbhdkey->serialized_private(),
		$script,
		$data,
		$i,
		SIGHASH_ALL
	);
	
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
