use strict;
use warnings;

use CBitcoin;
use JSON::XS;
use Data::Dumper;


use Test::More tests => 1;


use_ok( 'CBitcoin::Mnemonic' ) || print "Bail out!\n";

my $entropy;
{
	open(my $fh,'<','/dev/random') || print "Bail out!\n";
	my ($m,$n) = (0,32);
	while(0 < $n - $m){
		$m += sysread($fh,$entropy,$n - $m, $m);
	}
	close($fh);
}

my $result = CBitcoin::Mnemonic::entropyToMnemonic('en_us',$entropy);

warn "Result=$result\n";

__END__

