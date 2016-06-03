package CBitcoin::TransactionInput;

use strict;
use warnings;

use CBitcoin;
use CBitcoin::Script;

=head1 NAME

CBitcoin::TransactionInput - The great new CBitcoin::TransactionInput!

=head1 VERSION

Version 0.01

=cut

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::TransactionInput::VERSION = '0.1';

DynaLoader::bootstrap CBitcoin::TransactionInput $CBitcoin::VERSION;

@CBitcoin::TransactionInput::EXPORT = ();
@CBitcoin::TransactionInput::EXPORT_OK = ();


=item dl_load_flags

Don't worry about this.

=cut


sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

=item new

---++ new($info)

$info = {
	'prevOutHash' => 0x84320230,
	'prevOutIndex' => 32,
	'script' => 'OP_HASH160 ...'
};

=cut


sub new {
	my $package = shift;
	my $this = bless({}, $package);

	my $x = shift;
	unless(
		defined $x && ref($x) eq 'HASH' 
		&& defined $x->{'script'} && defined $x->{'prevOutHash'} 
		&& defined $x->{'prevOutIndex'} && $x->{'prevOutIndex'} =~ m/^\d+$/
	){
		return undef;
	}
	foreach my $col ('script','prevOutHash','prevOutIndex'){
		$this->{$col} = $x->{$col};
	}
	
	
	if($this->type_of_script() eq 'multisig'){
		$this->{'this is a p2sh'} = 1;
		
		# change the script to p2sh
		my $x = $this->{'script'};
		$x = CBitcoin::Script::script_to_address($x);
		die "no valid script" unless defined $x;
		$this->{'script'} = CBitcoin::Script::address_to_script($x);
		die "no valid script" unless defined $x;
	}
	elsif($this->type_of_script() eq 'p2sh'){
		$this->{'this is a p2sh'} = 1;
		
	}
	
	return $this;
}

=pod

---++ script

AKA scriptPubKey

=cut

sub script {
	return shift->{'script'};
}

=pod

---++ scriptSig

=cut

sub scriptSig {
	return shift->{'scriptSig'};
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

This is packed.

=cut

sub prevOutHash {
	return shift->{'prevOutHash'};

}

=item prevOutIndex

---++ prevOutIndex()

Not packed.

=cut

sub prevOutIndex {
	return shift->{'prevOutIndex'};
}

=item sequence

---++ sequence

=cut

sub sequence {
	return shift->{'sequence'} || 0;
}

=pod

---++ add_scriptSig($scriptSig)

For checking the signature or making a signature, we need the script that gets transformed into scriptPubKey.

=cut

sub add_scriptSig {
	my ($this,$script) = @_;
	die "bad script" unless defined $script && 0 < length($script);
	
	$this->{'scriptSig'} = $script;
	
	return $this->{'scriptSig'};
}

=pod

---++ add_cbhdkey($cbhd_key)

For making the signature, we need to add the $cbhd_key.

=cut

sub add_cbhdkey {
	my ($this,$cbhdkey) = @_;
	die "bad cbhd key" unless defined $cbhdkey && $cbhdkey->{'success'};
	$this->{'cbhd key'} = $cbhdkey;
	return $cbhdkey;
}


=pod

---+ i/o

=cut

=pod

---++ serialize

=cut

sub serialize {
	my ($this,$raw_bool) = @_;

	# scriptSig
	my $script = $this->scriptSig || '';
	
	if($raw_bool){
		return $this->prevOutHash().pack('L',$this->prevOutIndex()).
			CBitcoin::Utilities::serialize_varint(0).
			pack('L',$this->sequence());	
	}
	else{
		return $this->prevOutHash().pack('L',$this->prevOutIndex()).
			CBitcoin::Utilities::serialize_varint(length($script)).$script.
			pack('L',$this->sequence());
	}
	

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
