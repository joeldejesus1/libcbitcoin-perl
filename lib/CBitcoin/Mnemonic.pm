package CBitcoin::Mnemonic;


use utf8;
use strict;
use warnings;

use CBitcoin;
use Crypt::PBKDF2; # libcrypt-pbkdf2-perl
use Digest::SHA;
use Encode qw(decode encode);
use Unicode::Normalize;

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
my $word_index;

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

---++ word_index('en_us')->\%word_index

Return hash. {'word1' => 1}

=cut

sub word_index($){
	my ($language) = @_;
	# given en_us or en_gb, get english
	my $ln = $file_mapper->{$language};
	die "no language match" unless defined $ln;
	
	unless(defined $word_index->{$ln}){
		load_lang($ln);
	}
	
	if(defined $word_index->{$ln}){
		return $word_index->{$ln};
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
	
	$word_index = {} unless defined $word_index;
	$word_index->{$ln} = {} unless defined $word_index->{$ln};
	
	$content_mapper->{$ln} = [];
	open(my $fh,"<:encoding(UTF-8)",$fp) || die "bad read: $!";
	my $index = 0;
	while(my $word = <$fh>){
		chomp($word);
		push(@{$content_mapper->{$ln}},$word);
		$word_index->{$ln}->{$word} = $index;
		
		$index++;
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
		# contains zenkaku space
		return join('　',@seed_list);
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
#	warn "length=".length($entropy);
	
	return CBitcoin::Mnemonic::entropyToMnemonic($language,$entropy);
}

sub mnemonicSplit($$){
	my ($mnemonic,$language) = @_;
	my $wl = word_list($language);
	my @words;
	if($language eq 'ja_jp'){
		@words = split('　',$mnemonic);
	}
	else{
		@words = split(' ',$mnemonic);
	}
	
	unless(scalar(@words) % 3 == 0){
		die "invalid mnemonic - 1";
	}
	
	return @words;
}


sub mnemonicToEntropy($$){
	my ($mnemonic, $language) = @_;
	my @words = mnemonicSplit($mnemonic,$language);
	
	my $entropy;
	my $wi = word_index($language);
	foreach my $w (@words){
		my $i = $wi->{$w};
		die "out of index" unless defined $i;
		$entropy .= pack('C',$i);
	}
	#warn "entropy=".length($entropy);
	my $dividerIndex = int(length($entropy) / 33) * 32;
	#warn "di=$dividerIndex\n";
	my $entropyBits = substr($entropy,0,$dividerIndex );
	my $checksumBits = substr($entropy,$dividerIndex );
	
	#warn "bytes=".length($entropyBits);
	
	if(length($entropyBits) < 16 || 32 < length($entropyBits)){
		die "invalid entropy - 1";
	}
	unless(length($entropyBits) % 4 == 0){
		die "invalid entropy - 2";
	}
	
	my $calcChecksum = deriveChecksumBits($entropyBits);
		
	unless($calcChecksum eq $checksumBits){
		die "bad check sum";
	}
	
	return $entropyBits;
}

sub mnemonicToSeed($$$){
	my ($mnemonic,$language,$password) = @_;
	$password //= '';
	
	#my @words = mnemonicSplit($mnemonic,$language);
	#warn "m=$mnemonic";
	my $NFKD_string = Unicode::Normalize::NFKD($mnemonic);
	#warn "p - 1";
	my $pbkdf2 = Crypt::PBKDF2->new(
		hash_class => 'HMACSHA2',
		hash_args => {
			sha_size => 512,
		},
	    iterations => 2048,
	    salt_len => 10,
	);
	#warn "p - 2";
	
	return $pbkdf2->PBKDF2(encode('UTF-8',$NFKD_string),salt($password));
	
	#warn "p - 3 - h=".length($hash);
	
	#return $hash;
}


sub salt($){
	my $password = shift;
	$password //= '';
	return 'mnemonic'.$password;
}





1;