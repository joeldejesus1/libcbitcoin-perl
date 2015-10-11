package CBitcoin::SPV;

use strict;
use warnings;

use CBitcoin::Message;
use CBitcoin::Peer;
use Net::IP;


=pod

---+ new

Create a new SPV client.


=cut

sub new {
	my $package = shift;
	my $options = shift;
	$options ||= {};
	#my $this = CBitcoin::Message::spv_initialize(ip_convert_to_binary('0.0.0.0'),0);
	my $this = $options;
	bless($this,$package);
	return $this;
	
}



=pod

---+ Networking

=cut


=pod

---++ our_address

=cut

sub our_address {
	my $this = shift;
	my $binarybool = shift;
	if($binarybool){
		return [CBitcoin::Utilities::ip_convert_to_binary($this->{'address'}),$this->{'port'}];
	}
	else{
		return [$this->{'address'},$this->{'port'}];
	}
	
}


=pod

---++ add_peer($addr_recv_ip,$addr_recv_port)

=cut

sub add_peer{
	my $this = shift;
	my ($addr_recv_ip,$addr_recv_port) = (shift,shift);
	my $ref = $this->our_address();
	my $peer = CBitcoin::Peer->new({
		'address' => $addr_recv_ip, 'port' => $addr_recv_port,
		'our address' => $ref->[0], 'our port' => $ref->[1]
	});
	
	
	
	$this->{'peers'}->{$addr_recv_ip}->{$addr_recv_port} = $peer;
	
	return 1;
}

sub peer{
	my $this = shift;
	my ($ipaddress, $port) = (shift,shift);
	if(defined $this->{'peers'}->{$ipaddress}){
		return  $this->{'peers'}->{$ipaddress}->{$port};
	}
	return undef;
}


1;