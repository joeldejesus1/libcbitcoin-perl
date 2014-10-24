package CBitcoin::Script;

use 5.006;
use strict;
use warnings;

=head1 NAME

CBitcoin::Script - The great new CBitcoin::Script!

=head1 VERSION

Version 0.01

=cut

use Digest::SHA qw(sha256);

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Script::VERSION = '0.01';

DynaLoader::bootstrap CBitcoin::Script $CBitcoin::Script::VERSION;

@CBitcoin::Script::EXPORT = ();
@CBitcoin::Script::EXPORT_OK = ();

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking


=pod

---+ constructor

---++ new

{ 'address' => ..} or {'text' => ..}

=cut

sub address_to_script {
	#use bigint;
	my $x = shift;
	if(defined $x && $x =~ m/^([0-9a-zA-Z]+)$/){
		# addressToScript is a C function
		return addressToScript($x);
	}
	else{
		die "this is not an address($x)";
	}	
}

sub script_to_address {
	#use bigint;
	my $x = shift;
	# this part only works for OP_HASH160
	if(defined $x && $x =~ m/\s0x([0-9a-fA-F]{40}\s)/){
		# this is a C function
		return newAddressFromRIPEMD160Hash($1);
	}
	else{
		die "This is not a script($x).";
	}
}

=pod

---++ pubkeys_to_multisig_script(\@cbhdkeys,$m) 

Rule 1:<verbatim>$m < $n = scalar(@cbhdkeys)</verbatim>
=cut

sub pubkeys_to_multisig_script {
	my $KeyArrayRef = shift;
	my ($m,$n) = (shift,-1);

	unless(
		( defined $KeyArrayRef && defined $m )
		&& ( ref($KeyArrayRef) eq 'ARRAY' && $m =~ m/^\d+$/ )
		&& scalar(@{$KeyArrayRef}) >= $m && $m > 0
	){
		die "insufficient arguments to create script";
	}
	$n = scalar(@{$KeyArrayRef});
	

	#char* multisigToScript(SV* pubKeyArray,int mKeysInt, int nKeysInt)
	my @pubkeyarray;
	foreach my $key (@{$KeyArrayRef}){
		warn "Address:".$key->address()."  Public Key:".$key->publickey()."\n";
		push(@pubkeyarray,$key->publickey());
	}
	return multisigToScript(\@pubkeyarray,$m, $n);
}




=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-libperl-cbitcoin-script at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=libperl-cbitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CBitcoin::Script


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

1; # End of CBitcoin::Script
__END__
{
	# We need bigint or else the addresses will get screwed up upon conversion from ripemd160
	use bigint;
	my @b58 = qw{
      1 2 3 4 5 6 7 8 9
    A B C D E F G H   J K L M N   P Q R S T U V W X Y Z
    a b c d e f g h i j k   m n o p q r s t u v w x y z
	};

	my $b58 = qr/[@{[join '', @b58]}]/x;

	sub encode_base58 { my $_ = shift; $_ < 58 ? $b58[$_] : encode_base58($_/58) . $b58[$_%58] }
	
	sub ripemd160ToAddress {
		my $twentybyteHex = shift;
		if($twentybyteHex =~ m/([0-9a-fA-F]+)/){
			$twentybyteHex = $1;
		}
		else{
			return undef;
		}
		$twentybyteHex = lc($twentybyteHex);
		
		warn "KGC::Peerer::BitcoinJ::ripemd160ToAddress($twentybyteHex)\n";
		my @hex    = ($twentybyteHex =~ /(..)/g);
		my @dec    = map { hex($_) } @hex;
		my @bytes  = map { pack('C', $_) } @dec;
		my $hash = join( '', @bytes);
		my $checksum = substr sha256(sha256 chr(0).$hash), 0, 4;
		my $value = 0;
		for ( (chr(0).$hash.$checksum) =~ /./gs ) { $value = $value * 256 + ord }
			#(sprintf "%33s", encode_base58( $value) ) =~ y/ /1/r;
		$value = sprintf "%33s", encode_base58( $value);
		$value =~ y/ /1/r;
		return '1'.$value;	
	}
}