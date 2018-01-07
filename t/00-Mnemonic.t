use strict;
use warnings;

use CBitcoin;
use JSON::XS;
use Data::Dumper;


use Test::More tests => 2;


use_ok( 'CBitcoin::Mnemonic' ) || print "Bail out!\n";

my $lang = 'ja_jp';

my $result = CBitcoin::Mnemonic::generateMnemonic(256,$lang);

#warn "Result=$result\n";

my $entropy = CBitcoin::Mnemonic::mnemonicToEntropy($result,$lang);


ok(length(CBitcoin::Mnemonic::mnemonicToSeed($result,$lang,"")) == 64,'hash length');



__END__

