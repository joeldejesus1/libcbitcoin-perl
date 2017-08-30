#use 5.014002;
use strict;
use warnings;

use CBitcoin;
use CBitcoin::CBHD;
use CBitcoin::Transaction;
use CBitcoin::Script;
use CBitcoin::Tree;
use CBitcoin::Utilities::QRCodeTransfer;
use MIME::Base64;
use Crypt::CBC;
use Digest::SHA;
use Test::More tests => 7;

$CBitcoin::network_bytes = CBitcoin::REGNET;

my $other_root = CBitcoin::CBHD->generate("dajsoifjdsofjodsafj32h98funfsadjfn;");

# spending end point (serialized in the base64 encoded data below)
my $address = $other_root->deriveChild(1,30)->address();


my $xprv = CBitcoin::CBHD->new('tprv8ZgxMBicQKsPfAewoUg9THau9Dwz9XihsxbNWTHx1rsBtu9Dn5HEmnaosQKiAfoDFBLW3UNbeNqS996pWQnW2zRnh3hStfXqKdiB313WVSn');

#warn  "addr=".$xprv->address()."\n";

my $data = MIME::Base64::decode('AAFADQMAAPIFKgEAAABVAAEAAAAByUriURJI+w5TuYs1OI+5wFnRzRXoRkmWPYv5LPZjvA8AAAAAAP////8BAO3WJwAAAAAZdqkU1pSxSpn51z8sDzGwS7n4HF24lGmIrAAAAAAjACEDthaSEHj4EYf8ezoMJFQHSdFAtnp2vxJd80VyUMIseNus');


my $tree = CBitcoin::Tree->new(	
	["ROOT/CHANNEL","ROOT/SERVERS/2/CHANNEL","ROOT/CASH"]
	,{'base directory' => 't/db1', 'id' => 'wallet'}
);
$tree->hdkey_set("ROOT",$xprv);
$tree->max_i('+40');

# [qr count, 1B][fee, 4B][tx_data, ?B]
# [qr_i, 1B][data ...]


my ($qr_count,$fee,$total_in) = (0,0,0);
my $qr_i = unpack('C',substr($data,0,1));

my $raw_tx;
my @scriptPubs;
$data = substr($data,1);
if($qr_i == 0){
	#use bigint;
	$qr_count = unpack('C',substr($data,0,1));
	#warn "hex fee=".unpack('H*',substr($raw_tx,1,4));
	$fee = unpack('V',substr($data,1,4));
	$total_in = unpack('Q',substr($data,1+4,8));
	
	my $raw_tx_len = unpack('v',substr($data,1+4+8,2));
	#warn "raw tx len=$raw_tx_len";
	$raw_tx = substr($data,1+4+8+2,$raw_tx_len);
	
	die "bad raw tx length" unless $raw_tx_len == length($raw_tx);
	$data = substr($data,1+4+8+2+$raw_tx_len);
	
	
	while(0 < length($data)){
		my $size = unpack('v',substr($data,0,2));
		die "bad size" unless 0 < $size && $size < 10000;
		my $script = substr($data,2,$size);
		die "bad script length" unless $size == length($script);
		push(@scriptPubs,CBitcoin::Script::deserialize_script($script));
		$data = substr($data,2+$size);
	}
	
#	warn "count=$qr_count";
#	warn "fee=$fee";
#	warn "total_in=$total_in";
}
else{
#	warn "bad format: $qr_i";
}

my $tx = CBitcoin::Transaction->deserialize($raw_tx,\@scriptPubs);

my $signed_tx = $tree->paper_spend('ROOT/CASH',$fee,$total_in,$raw_tx,\@scriptPubs);

my $qr_transfer = CBitcoin::Utilities::QRCodeTransfer->new($signed_tx);

# store qr chunks here
my $qr_chunks = [];

my $dir = $qr_transfer->qrcode_write('./t',$qr_chunks);
if(opendir(my $fhdir,$dir)){
	foreach my $fn (readdir($fhdir)){
		next if $fn eq '.' || $fn eq '..';
		#warn "fp=$dir/$fn";
		if(!(-f "$dir/$fn")){
			warn "bad directory=$dir/$fn";
			print "Bail out!";
		}
		unlink("$dir/$fn");
	}
	closedir($fhdir);
}
else{
	print "Bail out!";
}

rmdir($dir);

my $receive_transfer = CBitcoin::Utilities::QRCodeTransfer->new();

{
	$receive_transfer->scan($qr_chunks->[2]);
	ok('0/0 X' eq $receive_transfer->scan_status,'checking');
}


{
	$receive_transfer->scan('fdf0923.....');
	ok('0/0 X' eq $receive_transfer->scan_status,'checking');
}

my @correct = (
	'1/4 O','2/4 O','3/4 O','4/4 O'
);
my $k=0;
foreach my $chunk (@{$qr_chunks}){
	$receive_transfer->scan($chunk);
	ok($correct[$k] eq $receive_transfer->scan_status,'checking');
	$k += 1;
}

ok($tx->validate_sigs($signed_tx),'tx validated');


__END__