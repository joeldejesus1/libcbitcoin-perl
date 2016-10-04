use strict;
use warnings;

use Kgc::HTML::Bitcoin::Tree;

use CBitcoin;
use CBitcoin::CBHD;
use CBitcoin::TransactionInput;
use CBitcoin::TransactionOutput;
use CBitcoin::Transaction;
use File::Slurp;

use Data::Dumper;

use Test::More tests => 1;

=pod

---+ Build Tree

Build out the default tree and set the root of the tree with the super secret xprv CBHD key.

=cut

my $xstring = File::Slurp::read_file( '.secret' );
my $xprv = CBitcoin::CBHD->new($xstring);
die "no xprv" unless defined $xprv;

$CBitcoin::network_bytes = CBitcoin::TESTNET;



my $tree = Kgc::HTML::Bitcoin::Tree->new(	
	["ROOT/CHANNEL","ROOT/SERVERS/2/CHANNEL","ROOT/CASH"]
);

$tree->hdkey_set("ROOT",$xprv);
$tree->max_i('+40');

ok('n1KKWuBaKw3akvUbWaYdoRYmU1receRGGT' eq $tree->deposit("ROOT/CASH"), 'Got correct deposit');


{
	# Got 0.301 sent to n1KKWuBaKw3akvUbWaYdoRYmU1receRGGT
	# scan the transaction
	#my $txdata = pack('H*',File::Slurp::read_file( '.data/tx1' ));
	
}


# mgae6AK7dPpahnnh8b9eHpoLzxX5qb9NtF 




__END__

#require Data::Dumper;
#print "Final\n".Data::Dumper::Dumper($tree)."\n";

#print "part 2\n";
my $string = $tree->export("ROOT/SERVERS/2/CHANNEL",'address');

print "S=$string\n";


# do deposits

$string = $tree->deposit(2,2,"ROOT/CASH","ROOT/CHANNEL");

print "Deposit=$string\n";

# set max_i

$tree->max_i('+5');


# add transactions

{
	my @inputs = (
		{
			'hash' => '60163bdd79e0b67b33eb07dd941af5dfd9ca79b85866c9d69993d95488e71f2d'
			,'index' => 3
			,'script' => 'OP_DUP OP_HASH160 0x'.
				unpack('H*',$tree->export("ROOT/CASH",'ripemdHASH160') )
				.' OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.01032173*100000000
		}
		,{
			'hash' => '353082e37e57d2006517db8b6a75d905c49ae528cfff523a959a4fbf44203860'
			,'index' => 0
			,'script' => 'OP_DUP OP_HASH160 0x'.
				unpack('H*',$tree->export("ROOT/CASH",'ripemdHASH160') )
				.' OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.00119999*100000000		
		}
	);
	my $i = 1;
	my @ins;
	foreach my $in (@inputs){
		my $address = CBitcoin::Script::script_to_address($in->{'script'});
		# warn "Address=".$root->deriveChild(1,$i)->address()."\n";
		$i++;
		push(@ins,CBitcoin::TransactionInput->new({
			'prevOutHash' => pack('H*',$in->{'hash'}) #should be 32 byte hash
			,'prevOutIndex' => $in->{'index'}
			,'script' => $in->{'script'} # scriptPubKey
		}));
		
		
	}
	my @outputs = (
		{
			'address' => '198Lb2wtUEMzAAMdxBjqhGsUPG1RkKFUgh'
			,'script' => 'OP_DUP OP_HASH160 0x592444aa94e0d8a06442c73f2dc56c5c11de7c5b OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.010173*100_000_000
		}
		,{
			'address' => '1L9cXroh15fCoegiNqbsrxZg7wemc7a2r1'
			,'script' => 'OP_DUP OP_HASH160 0xd20b60d4a931079074d43c92fc4686dc37ac5f7b OP_EQUALVERIFY OP_CHECKSIG'
			,'value' => 0.010472*100_000_000
		}
	);
	my @outs;
	foreach my $x (@outputs){
		push(@outs,CBitcoin::TransactionOutput->new($x));
	}

	my @hashes = (
		'6105e342232a9e67e4fa4ee0651eb8efd146dc0d7d346c788f45d8ad591c4577',
		'da16a3ea5101e9f2ff975ec67a4ad85767dd306c27b94ef52500c26bc88af5c9'
	);
	my $tx = CBitcoin::Transaction->new({
		'inputs' => \@ins, 'outputs' => \@outs
	});

	# add transactions to the database
	$tree->tx_add($tx);
}


