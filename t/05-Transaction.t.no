use 5.014002;
use strict;
use warnings;


use Test::More tests => 1;

require CBitcoin::Script;
require CBitcoin::TransactionInput;
require CBitcoin::TransactionOutput;
require CBitcoin::Transaction;

my $txhash = 'a4e56cf47b0c853d5a9206b262b30bea5dc336926626558e9419e5769f326e07';
my @outputs = (
	{
		'address' => '198Lb2wtUEMzAAMdxBjqhGsUPG1RkKFUgh'
		,'script' => 'OP_DUP OP_HASH160 0x592444aa94e0d8a06442c73f2dc56c5c11de7c5b OP_EQUALVERIFY OP_CHECKSIG'
		,'value' => 0.01032173*100000000
	}
	,{
		'address' => '1L9cXroh15fCoegiNqbsrxZg7wemc7a2r1'
		,'script' => 'OP_DUP OP_HASH160 0xd20b60d4a931079074d43c92fc4686dc37ac5f7b OP_EQUALVERIFY OP_CHECKSIG'
		,'value' => 0.01042172*100000000
	}
);




my @inputs = (
	{
		'data' => '3045022100e2a8aeffa78232e897d11e620649ca800d858f727785a55bf4c3c75464d4c29d0220184a698d48e94da4d5fe52fd293cbea31231d61e9bece1c080a6f4e54bc38d4e01'
		,'hash' => '60163bdd79e0b67b33eb07dd941af5dfd9ca79b85866c9d69993d95488e71f2d'
		,'index' => 0
		,'address' => '1JfkgyctXCT1N7sWm3Bcf7oSp51fEcmta9'
		,'script' => 'OP_DUP OP_HASH160 0xc1ce6a3171f3ad0452070b7a5a52315b84a94951 OP_EQUALVERIFY OP_CHECKSIG'
		,'value' => 0.01032173*100000000
	}
	,{
		'data' => '304402204c2aa2c3f343dfa9acd45620e7485e8c7f00e2f67a5876f2ed1ab7dc6bc459af02207c065ef4bfa81b5fc3b98dd124a5a6cf84799034bd37e50ed848f298b96d915301'
		,'hash' => '353082e37e57d2006517db8b6a75d905c49ae528cfff523a959a4fbf44203860'
		,'index' => 0
		,'address' => '1PwB5UYC1rL2Dsmsri68hhS4E8x6abwULP'
		,'script' => 'OP_DUP OP_HASH160 0xfb91a42334c73c391ab6a81e337d51ce14ee22f7 OP_EQUALVERIFY OP_CHECKSIG'
		,'value' => 0.00119999*100000000		
	}
);

my $j = 0;
my @ins;

foreach my $in (@inputs){
	$j++;
	
	push(@ins,
		CBitcoin::TransactionInput->new({
			'prevOutHash' => $in->{'hash'}
			,'prevOutIndex' => $in->{'index'}
			,'script' => $in->{'script'}
		})
	);
}

my @outs;

foreach my $in (@outputs){
	$j++;
	#warn "Data:".$in->{'data'}."\n";
	

	push(@outs,
		CBitcoin::TransactionOutput->new({
			'value' => $in->{'value'}
			,'script' => $in->{'script'}
		})	
	);

}

# create a transaction
my $tx = CBitcoin::Transaction->new({
	'inputs' => \@ins
	,'outputs' => \@outs
});


ok ( $tx->numOfInputs , 'Testing Tx: '.1) || print "Bail out!\n";



