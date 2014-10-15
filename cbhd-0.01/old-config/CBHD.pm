## This file generated by InlineX::C2XS (version 0.22) using Inline::C (version 0.5)
package CBitcoin::CBHD;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::CBHD::VERSION = '0.02';

DynaLoader::bootstrap CBitcoin::CBHD $CBitcoin::CBHD::VERSION;

@CBitcoin::CBHD::EXPORT = ();
@CBitcoin::CBHD::EXPORT_OK = ();

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking


# Preloaded methods go here.


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
# newMasterKey deriveChildPrivate exportWIFFromCBHDKey exportAddressFromCBHDKey publickeyFromWIF
# generate a key (parent)
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
=pod

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

sub childid {
	my $this = shift;
	return (exportPrivChildIDFromCBHDKey($this->{'data'}),exportChildIDFromCBHDKey($this->{'data'}));
}


1;
