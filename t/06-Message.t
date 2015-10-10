use 5.014002;
use strict;
use warnings;

use CBitcoin::Message;

use Test::More tests => 1;

my $input = "eat my socks mofo";
my $x = CBitcoin::Message::testmsg($input,length($input));
my $y = CBitcoin::Message::testmsg2('32');
warn "what?=$y";
require Data::Dumper;
my $xo = Data::Dumper::Dumper($x);

warn "X=$xo\n";

ok(1) || print "Bail out!";
