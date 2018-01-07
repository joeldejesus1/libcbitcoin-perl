use strict;
use warnings;

use CBitcoin;
use JSON::XS;
use Data::Dumper;


use Test::More tests => 1;


use_ok( 'CBitcoin::Mnemonic' ) || print "Bail out!\n";



my $result = CBitcoin::Mnemonic::generateMnemonic(256,'ja_jp');

warn "Result=$result\n";



__END__

