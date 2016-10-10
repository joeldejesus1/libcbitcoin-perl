package CBitcoin::BloomFilter;

use strict;
use warnings;

=head1 NAME

CBitcoin::Message

=head1 VERSION

Version 0.01

=cut

use CBitcoin;

require Exporter;
*import = \&Exporter::import;
#require DynaLoader;

#$CBitcoin::Message::VERSION = '0.2';

#DynaLoader::bootstrap CBitcoin::Message $CBitcoin::Message::VERSION;

@CBitcoin::BloomFilter::EXPORT = ();
@CBitcoin::BloomFilter::EXPORT_OK = ();



=pod

---+ Constructors

=cut

=pod

---++ new(\%options)

Need:
   * nHashFuncs (default is 1000?)
   * FalsePositiveRate (default is 0.001, which is 0.1%)

=cut




sub new {
	my $package = shift;
	
	my $options = shift;
	
	my $this = {
		'raw' => {},'scripts' => {}, 'prevOutPoints' => {}, 'data' => ''
	};
	bless($this,$package);
	
	die "no options" unless defined $options && ref($options) eq 'HASH'
		&& defined $options->{'nHashFuncs'} && $options->{'nHashFuncs'} =~ m/^\d+$/
		&& defined $options->{'FalsePostiveRate'} 
		&& $options->{'FalsePostiveRate'} =~ m/^\d+(\.\d+)?$/
		&& 0 < $options->{'FalsePostiveRate'} && $options->{'FalsePostiveRate'} < 1;
	$this->{'nHashFuncs'} = $options->{'nHashFuncs'};
	$this->{'FalsePostiveRate'} = $options->{'FalsePostiveRate'};

	return $this;
}

=pod

---+ Getters/Setters

=cut

sub prevOuts {
	return shift->{'prevOuts'};
}

sub scripts {
	return shift->{'scripts'};
}

sub raw {
	return shift->{'raw'};
}

sub data {
	my $this = shift;
	unless(defined $this->{'data'} && 0 < length($this->{'data'})){
		$this->bloomfilter_calculate();
	}
	return $this->{'data'};
}


=pod

---+ Subroutines


=cut

=pod

---++ add_outpoint($prevHash,$prevIndex)

Serialize the bloom filter to be used in CBitcoin::Bitcoin::deserialize_filter();

=cut


sub add_outpoint {
	my ($this,$prevHash,$prevIndex) = @_;
	die "bad index" unless defined $prevIndex && $prevIndex =~ m/^(\d+)$/;
	die "no hash defined" unless defined $prevHash;
	if(length($prevHash) == 32){
		# change to hex
		$this->{'prevOuts'}->{unpack('H*',$prevHash)}->{$prevIndex} = 1;
	}
	elsif($prevHash =~ m/^([0-9a-fA-F]{64})$/){
		# change to hex
		$this->{'prevOuts'}->{$prevHash}->{$prevIndex} = 1;
		
	}
	else{
		die "prevHash is in a bad format";
	}
	
}

=pod

---++ add_script($serialized_script)

Serialize the bloom filter to be used in CBitcoin::Bitcoin::deserialize_filter();

=cut


sub add_script {
	my ($this,$script) = @_;
	die "no script" unless defined $script && 2 < length($script) && length($script) < 1000;
	$this->{'scripts'}->{$script} = 1;
}

=pod

---++ add_raw($rawdata)

Just add data to put into the bloom filter.

=cut


sub add_raw {
	my ($this,$raw) = @_;
	die "no raw data" unless defined $raw && 0 < length($raw) && length($raw) < 1000;
	$this->{'raw'}->{$raw} = 1;
}

=pod

---++ set_data($data)

Set data.

=cut

sub set_data{
	my ($this,$data) = @_;
	return undef unless defined $data && 0 < length($data);
	
	$this->{'data'} = $data;
}


=pod

---++ bloomfilter_calculate()

Serialize the bloom filter to be used in CBitcoin::Bitcoin::deserialize_filter();

=cut



sub bloomfilter_calculate {
	my ($this) = @_;
	
	my @values = (keys %{$this->{'scripts'}},keys %{$this->{'prevOuts'}}, keys %{$this->{'raw'}});
	
	if(scalar(@values) == 0){
		$this->{'data'} = undef;
		return undef;
	}
	
	my $bfhash = CBitcoin::Block::picocoin_bloomfilter_new(
		\@values,
		$this->{'nHashFuncs'},
		$this->{'FalsePostiveRate'}
	);
	
	die "failed to get bloom filter" unless $bfhash->{'success'};
	
	$this->{'data'} = $bfhash->{'data'};
	
	return $this->{'data'};
}

=pod

---++ tx_filter([tx from block])->\%$txhash

Once the bloom filter gets the likely candidates for transactions we want, we need to check which ones we actually intended to keep.

Input is the array of transactions from a deserialized block.  The output is a hash mapping with name=$tx->{'hash'} and value=$tx.

If you want to calculate merkle hashes at some point, set $keep_txhashes=1.

=cut

sub tx_filter {
	my ($this,$tx_ref,$keep_txhashes) = @_;
	
	die "no tx ref provided" unless defined $tx_ref && ref($tx_ref) eq 'ARRAY';
	
	my $prevOut_H = $this->{'prevOuts'};
	my $script_H = $this->{'scripts'};
	my $raw_H = $this->{'raw'};
	my $txhash = {'_merkle' => []};
	foreach my $tx_H (@{$tx_ref}){
		#$tx_H->{'hash'};
		#warn "tx=".Data::Dumper::Dumper($tx_H->{'vin'})."\n";
		my $keep_bool = 0;
		if(
			0 < scalar(keys %{$prevOut_H}) || 0 < scalar(keys %{$script_H}) || 0 < scalar(keys %{$raw_H})		
		){
			foreach my $vin (@{$tx_H->{'vin'}}){
				#next unless defined $vin;
				last if $keep_bool;
				$vin->{'prevHash'} = substr($vin->{'prevHash'},0,64);
				if(
					$prevOut_H->{$vin->{'prevHash'}}
					&& $prevOut_H->{$vin->{'prevHash'}}->{$vin->{'prevIndex'}}
				){
					$tx_H->{'matched'} = 'prevHash';
					$keep_bool = 1;
				}
			}
			foreach my $vout (@{$tx_H->{'vout'}}){
				last if $keep_bool;
				
				# script
				if($script_H->{$vout->{'script'}}){
					$tx_H->{'matched'} = 'script';
					$keep_bool = 1;
				}
			}
			
		}
		else{
			$keep_bool = 1;
		}

		$tx_H->{'hash'} = substr($tx_H->{'hash'},0,64);
		
		if($keep_bool){	
			$txhash->{$tx_H->{'hash'}} = $tx_H;
		}
		
		if($keep_txhashes){
			push(@{$txhash->{'_merkle'}},pack('H*',$tx_H->{'hash'}));
		}
	}
	return $txhash;
}



=head1 AUTHOR

Joel De Jesus, C<< <dejesus.joel at e-flamingo.jp> >>

=head1 BUGS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Joel De Jesus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of CBitcoin::Transaction
