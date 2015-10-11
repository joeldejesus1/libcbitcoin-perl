use 5.014002;
use strict;
use warnings;

use CBitcoin::Message;

use Test::More tests => 1;



my $input = "eat my socks mofo";
my $x = CBitcoin::Message::testmsg($input,length($input));

my $y = CBitcoin::Message::getversion1(CBitcoin::Message::ip_convert_to_binary('2001:0db8:3c4d:0015:0000:0000:abcd:ef12'),'32');
$y->{'address'} = CBitcoin::Message::ip_convert_to_string($y->{'address'});

require Data::Dumper;
my $xo = Data::Dumper::Dumper($y);

warn "X=$xo\n";

ok(1) || print "Bail out!";
