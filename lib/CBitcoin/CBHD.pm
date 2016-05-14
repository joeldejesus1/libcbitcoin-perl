package CBitcoin::CBHD;

#use 5.014002;
use strict;
use warnings;


=head1 NAME

CBitcoin::CBHD - The great new CBitcoin::CBHD!

=head1 VERSION

Version 0.2

=cut

#use XSLoader;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::CBHD::VERSION = '0.1';

#XSLoader::load('CBitcoin::CBHD',$CBitcoin::CBHD::VERSION );
DynaLoader::bootstrap CBitcoin::CBHD $CBitcoin::CBHD::VERSION;

@CBitcoin::CBHD::EXPORT = ();
@CBitcoin::CBHD::EXPORT_OK = ();


=item dl_load_flags

Don't worry about this.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking


# Preloaded methods go here.

=item new

---+ new()

Create a cbhd object.

=cut

sub new {
	my $package = shift;
	my $seed = shift;
	my $this = {};
	bless($this, $package);
	if(defined $seed){
		$this->serialized_data($seed);
	}
	return $this;
}

=item generate

---+ generate

newMasterKey deriveChildPrivate exportWIFFromCBHDKey exportAddressFromCBHDKey publickeyFromWIF

generate a key (parent)

=cut


sub generate {
	my $this = shift;
	eval{
		my $key = CBitcoin::CBHD::newMasterKey(1);
		$this->serialized_data($key) || die "Cannot load the key.";		
	};
	if($@){
		return 0;
	}
	return 1;
}

=item serialized_data

---+ serialized_data


=cut


sub serialized_data {
	my $this = shift;
	my $x = shift;
	if(defined $x && $x =~ m/^([0-9a-zA-Z]+)$/){
		$this->{'data'} = $x;
		return $this->{'data'};
	}
	elsif(!(defined $x)){
		return $this->{'data'};
	}
	else{
		die "no arguments to create CBitcoin::CBHD data";
	}
}

=item is_soft_child

---+ is_soft_child

Returns true if yes, false if soft.
=cut


sub is_soft_child {
	my $this = shift;
	exportPrivChildIDFromCBHDKey();
	return shift->{'is soft child'};
}

=item deriveChild

---++ deriveChild($hardbool,$childid)

If you want to go from private parent keypair to public child keypair, then set $hardbool to false.  If you want to 
go from private parent keypair to private child keypair, then set $hardbool to true.

=cut

sub deriveChild {
	my $this = shift;
	my $hardbool = shift;
	my $childid = shift;
	my $childkey = new CBitcoin::CBHD;
	eval{
		if($hardbool){
			$hardbool = 1;
		}
		else{
			$hardbool = 0;
			$childkey->{'is soft child'} = 1;
		}
		unless($childid > 0 && $childid < 2**31){
			die "The child id is not in the correct range.\n";
		}
		die "no private key" unless $this->serialized_data;
		$childkey->serialized_data(CBitcoin::CBHD::deriveChildPrivate($this->serialized_data(),$hardbool,$childid));
		
	};
	if($@){
		return undef;
	}
	return $childkey;
	
}


=item deriveChildPubExt

---++ deriveChildPubExt($childid)

If you want to take an CBHD key with private key and create a soft child that does not have the private bits, then use this function.

From Hard to Soft.

=cut

sub deriveChildPubExt {
	my $this = shift;
	my $childid = shift;
	my $childkey = new CBitcoin::CBHD;
	eval{

		unless($childid > 0 && $childid < 2**31){
			die "The child id is not in the correct range.\n";
		}
		die "no private key" unless $this->serialized_data;
		$childkey->serialized_data(CBitcoin::CBHD::deriveChildPublicExtended($this->serialized_data(),$childid));
		$childkey->{'is soft child'} = 1;
	};
	if($@){
		warn "Error:$@";
		return undef;
	}
	return $childkey;
	
}

=item exportPublicExtendedCBHD

---++ exportPublicExtendedCBHD

=cut


sub exportPublicExtendedCBHD {
	my $this = shift;
	# better make sure we have the private bits
	return ref($this)->new(exportPublicExtendedKey($this->serialized_data()));
}

=item network_bytes

---++ network_bytes

=cut

sub network_bytes {
	my $ans = exportNetworkBytes(shift->serialized_data());
	if($ans == 1){
		return 'production';
	}
	elsif($ans == 2){
		return 'test';
	}
	else{
		return 'unknown';
	}
}


=item cbhd_type

---++ cbhd_type

=cut

sub cbhd_type {
	my $ans = exportCBHDType(shift->serialized_data());
	if($ans == 1){
		return 'private';
	}
	elsif($ans == 2){
		return 'public';
	}
	else{
		return 'unknown';
	}
}


=item WIF

---++ $cbhd->WIF()

=cut


sub WIF {
	my $this = shift;
	my $wif = '';
	eval{
		die "no private key" unless $this->serialized_data();
		$wif = CBitcoin::CBHD::exportWIFFromCBHDKey($this->serialized_data());
	};
	if($@){
		return undef;
	}
	return $wif;
}

=item address

---++ address()

=cut

sub address {
	my $this = shift;
	my $address = '';
	eval{
		die "no private key" unless $this->serialized_data();
		$address = CBitcoin::CBHD::exportAddressFromCBHDKey($this->serialized_data());
	};
	if($@){
		return undef;
	}
	return $address;
}

=item publickey

---++ $cbhd->publickey()

=cut

sub publickey {
	my $this = shift;
	my $x = '';
	eval{
		die "no private key" unless $this->serialized_data();
		$x = CBitcoin::CBHD::exportPublicKeyFromCBHDKey($this->serialized_data());
	};
	if($@){
		return undef;
	}
	return $x;
}


=item print_to_stderr

=cut

sub print_to_stderr {
	my $this = shift;
	warn "version=".$this->{'version'}."\n";
	warn "Depth=".$this->{'depth'}."\n";
	warn "index=".$this->{'index'}."\n";
	warn "success=".$this->{'success'}."\n";
	warn "serialized private=".unpack('H*',$this->{'serialized private'})."\n";
	warn "serialized public=".unpack('H*',$this->{'serialized public'})."\n";
	warn "Depth=".$this->{'depth'}."\n";

}


=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-cbhd at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::CBHD


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

1; # End of CBitcoin::CBHD
