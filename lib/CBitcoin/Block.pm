package CBitcoin::Block;

use 5.014002;
use strict;
use warnings;

=head1 NAME

CBitcoin::Block

=head1 VERSION

Version 0.01

=cut


use bigint;
use CBitcoin::Script;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Transaction;
use Digest::SHA;

use constant MAINNET    => 0xd9b4bef9, TESTNET => pack('L',0xdab5bffa), TESTNET3 => pack('L',0x0709110b), NAMECOIN => pack('L',0xfeb4bef9) ;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$CBitcoin::Block::VERSION = '0.2';

DynaLoader::bootstrap CBitcoin::Block $CBitcoin::Block::VERSION;

@CBitcoin::Block::EXPORT = ();
@CBitcoin::Block::EXPORT_OK = ();


=item dl_load_flags

Nothing to see here.

=cut

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

=pod

---++ genesis_block

Return a block header that has been deserialized.

=cut

sub genesis_block{
	my $package = shift;
	
	my $ref = block_GenesisBlock();
	
	return $package->new($ref);
}


sub new {
	my $package = shift;
	my $this = shift;
	$this = {} unless defined $this && ref($this) eq 'HASH';
	
	# must do a sanity check??
	
	bless($this,$package);
	
	return $this;
}

sub serialize_header {
	my $package = shift;
	my $data = shift;
	my $txbool = shift;
	if($txbool){
		$txbool = 1;
	}
	else{
		$txbool = 0;
	}
	

	my $ref = block_BlockFromData($data,$txbool);
	
	return undef unless $ref->{'result'};
	
	return $package->new($ref);
}

=pod

---+ Getters/Setters

=cut

sub timestamp {
	return shift->{'timestamp'};
}

sub target {
	return shift->{'target'};
}

sub nonce {
	return shift->{'nonce'};
}

sub version {
	return shift->{'version'};
}

sub transactionNum {
	return shift->{'transactionNum'};
}




sub merkleRoot {
	return shift->{'merkleRoot'};
}

sub merkleRoot_hex {
	return unpack('H*',shift->{'merkleRoot'});
}


sub prevBlockHash {
	return shift->{'prevBlockHash'};
}

sub prevBlockHash_hex {
	return unpack('H*',shift->{'prevBlockHash'});
}


sub hash {
	return shift->{'hash'};
}

sub hash_hex {
	return unpack('H*',shift->{'hash'});
}

sub data {
	return shift->{'data'};
}

sub error_print {
	my $this = shift;
	my $printsub = shift;
	$printsub->('hash:'.$this->hash_hex());
	$printsub->('prevBlockhash:'.$this->prevBlockHash_hex());
	$printsub->('merkleRoot_hex:'.$this->merkleRoot_hex());
	$printsub->('version:'.$this->version());
	$printsub->('nonce:'.$this->nonce());
	$printsub->('timestamp:'.$this->timestamp());
	$printsub->('transactionNum:'.$this->transactionNum());
	$printsub->('target:'.$this->target());

}

1;