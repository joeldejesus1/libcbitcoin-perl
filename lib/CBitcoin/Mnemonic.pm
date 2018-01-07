package CBitcoin::Mnemonic;


use utf8;
use strict;
use warnings;

use CBitcoin;
use Crypt::PBKDF2; # libcrypt-pbkdf2-perl
use Digest::SHA;
use Encode qw(decode encode);

# libjson-xs-perl libfile-sharedir-perl
#  libgmp-dev libssl-dev


our $PARAM_LANG = 'language';

our $DEFAULT_LANG = 'en_us';

our $CONST_JAPANESE_SPACE = '　';

=pod

This BIP describes the implementation of a mnemonic code or mnemonic sentence -- a group of easy to remember words -- for the generation of deterministic wallets.

It consists of two parts: generating the mnemonic, and converting it into a binary seed. This seed can be later used to generate deterministic wallets using BIP-0032 or similar methods. 


Copying https://github.com/dark-s/bitcore-bip39/blob/master/lib/bip39/index.js

=cut


=pod

---+ constructors

=cut

my $content_mapper;

my $file_mapper = {
	'en_us' => 'english'
	,'ja_jp' => 'japanese'
	,'ko_kr' => 'korean'
	,'it_it' => 'italian'
	,'es_es' => 'spanish'
	,'fr_fr' => 'french'
	,'zh_cn' => 'chinese-simplified'
	,'zh_tw' => 'chinese-traditional'
};


=pod

---+ getters/setters

=cut

=pod

---++ word_list('en_us')->\@lang

Return array.

=cut

sub word_list($){
	my ($language) = @_;
	# given en_us or en_gb, get english
	my $ln = $file_mapper->{$language};
	die "no language match" unless defined $ln;
	
	unless(defined $content_mapper->{$ln}){
		load_lang($ln);
	}
	
	if(defined $content_mapper->{$ln}){
		return $content_mapper->{$ln};
	}
	else{
		die "no language match";
	}

}

=pod

---++ module_directory

=cut

sub module_directory{
	return CBitcoin::module_directory().'/Mnemonic';
}

=pod

---+ utilities

=cut

=pod

---++ load_lang('english')

=cut

sub load_lang($){
	my ($ln) = @_;
	
	my $fp = module_directory().'/'.$ln.'.txt';
	
	die "no language file" unless -f $fp;
	
	$content_mapper->{$ln} = [];
	open(my $fh,"<:encoding(UTF-8)",$fp) || die "bad read: $!";
	while(my $word = <$fh>){
		chomp($word);
		push(@{$content_mapper->{$ln}},$word);
	}
	close($fh);
	
}


sub entropyToMnemonic($$){
	my ($language,$entropy) = @_;
	
	if(length($entropy) < 32 || 64 < length($entropy) ){
		die "invalid entropy - 1";
	}
	
	if (length($entropy) % 4 != 0){
		die "invalid entropy - 2";
	}
	
	my $checksumBits = deriveChecksumBits($entropy);
	
	my $data = $entropy.$checksumBits;
	
	my $wl = word_list($language);
	
	my @seed_list;
	for(my $i=0;$i<length($data);$i++){
		my $ith_byte = unpack('C',substr($data,$i,1));
		die "bad index" unless defined $wl->[$ith_byte];
		push(@seed_list,$wl->[$ith_byte]);
	}
	
	
	
	if($language eq 'ja_jp'){
		return join('　',@seed_list);

=pod
		my $d = '';
		my $i = 0;
		foreach my $sl (@seed_list){
			$i++;
			if($i == scalar(@seed_list)){
				next;
			}
			#$d .= decode('UTF-8',$sl)."　";
			$d .= $sl."　";		
		}
		return $d;
=cut
	}
	else{
		return join(' ',@seed_list);
	}
	
}

sub deriveChecksumBits($){
	my $entropy = shift;
	
	# change to bits
	my $ENT = length($entropy) * 8;
	die "no entropy" unless 0 < $ENT;
	my $CS = $ENT / 32;

	my $hash = Digest::SHA::sha256($entropy);
	# change back to bytes
	return substr($hash,0,$CS / 8);
}

# (strength_bits=256,)
sub generateMnemonic($$){
	my ($strength,$language) = @_;
	
	unless($strength % 32 == 0){
		die "strength must be multiple of 32";
	}
	
	my $entropy;
	open(my $fh,'<','/dev/random') || print "Bail out!\n";
	my ($m,$n) = (0,$strength / 8);
	while(0 < $n - $m){
		$m += sysread($fh,$entropy,$n - $m, $m);
	}
	close($fh);
	warn "length=".length($entropy);
	
	return CBitcoin::Mnemonic::entropyToMnemonic($language,$entropy);
}


1;