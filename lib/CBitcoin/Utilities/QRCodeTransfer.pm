package CBitcoin::Utilities::QRCodeTransfer;

use utf8;
use strict;
use warnings;

use CBitcoin::Utilities;
use Image::PNG::QRCode 'qrpng';
use MIME::Base64;

=pod

Use this module to transfer data via QR codes.

Split a serialized binary blob into qr code readable chunks.

Format of data: [qr_total, 1B][data, ?B]

Per qr code: [qr_i, 1B][data, ?B]

=cut

=pod

---+ constructors

=cut


=pod

---++ new

=cut

sub new{
	my $package = shift;
	
	my $this = {
		'current' => 0
		,'total' => 0
		,'last_scan' => 0
		,'scans' => []
	};
	bless($this,$package);
	
	my $data = shift;
	# if defined, then data is being sent
	$this->data($data) if defined $data;
	
	return $this;
}

=pod

---+ getters/setters

=cut

=pod

---++ last_scan

Boolean, was the last scan successful?

=cut

sub last_scan{
	my ($this,$x) = @_;
	if(defined $x && $x){
		$this->{'last_scan'} = 1;
	}
	elsif(defined $x){
		$this->{'last_scan'} = 0;
	}
	return $this->{'last_scan'};
}


=pod

---++ total

How many qr codes in total need to be scanned.

=cut

sub total{
	my ($this,$x) = @_;
	
	my $v = 'total';
	
	if(defined $x && $x =~ m/^(\d+)$/){
		$this->{$v} = $1;
	}
	elsif(defined $x){
		die "bad $v number";
	}
	
	return $this->{$v};
}

=pod

---++ current

Is the qr code which was last successfully scanned.

=cut

sub current{
	my ($this,$x) = @_;
	
	my $v = 'current';
	
	if(defined $x && $x =~ m/^(\d+)$/){
		$this->{$v} = $1;
	}
	elsif(defined $x){
		die "bad $v number";
	}
	
	return $this->{$v};
}



=pod

---+ Reading

=cut


=pod

---++ scan($content)

Read in the content from a scan.

=cut

sub scan($$){
	my ($this,$content) = @_;
	
	if(length($content) < 3){
		return $this->last_scan(0);
	}
	
	eval{
		my $data = MIME::Base64::decode($content);
		my $qr_count = unpack('C',substr($data,0,1));
		
		if($this->current != $qr_count){
			return $this->last_scan(0);
		}
		else{
			my $start = 1;
			if($this->current == 0){
				# get total
				my $qr_total = unpack('C',substr($data,1,1));
				$start = 2;
				$this->total($qr_total + 1);
			}
			
			$this->{'scans'}->[$this->current] = substr($data,$start);
		}
		
		$this->current($qr_count + 1);
	} || do{
		my $error = $@;
		return $this->last_scan(0);
	};
	
	return $this->last_scan(1);
}


=pod

---++ scan_status

What is the status of the last scan.

Returns something like "1/4 X", meaning 1 qr code has been scanned, but the last attempted scan failed.  And there are a total of 4 qr codes that need to be scanned.

=cut

sub scan_status($){
	my ($this) = @_;
	
	my $total = $this->total;
	my $current = $this->current;
	my $status = 'O';
	unless($this->last_scan()){
		$status = 'X';
	}
	
	return "$current/$total $status";
}



=pod

---+ Writing

=cut

=pod

---++ data

=cut

sub data($){
	my ($this,$data) = @_;
	if(defined $data && 3 < length($data)){
		$this->{'data'} = $data;
	}
	elsif(defined $data){
		die "no data";
	}
	return $this->{'data'};
}

=pod

---++ qrcode_write($directory)->$dir

Write qrcodes to disk as png files.  The file names in the newly created directory are in the patter of:$i.png where $i is an integer starting from 0.

=cut

sub qrcode_write{
	my ($this,$directory,$array_ref) = @_;

	if(defined $array_ref && ref($array_ref) ne 'ARRAY'){
		die "bad array reference";
	}
	$array_ref //= [];

	# following was taken from CBitcoin::Utilites, hence the old variable names
	my ($data,$basedir) = ($this->data,$directory);
	unless(defined $data && 4 < length($data)){
		die "bad data";
	}
	
	if(defined $basedir && $basedir =~ CBitcoin::Utilities::validate_filepath($basedir)){
		$basedir = CBitcoin::Utilities::validate_filepath($basedir);
	}
	elsif(defined $basedir){
		die "bad base directory";
	}
	else{
		$basedir = '/tmp';
	}

	$basedir .= '/'.CBitcoin::Utilities::generate_random_filename(12);
	mkdir($basedir) || die "failed to make directory (d=$basedir)";
	
	
	my $ans = [];
	
	return $ans unless defined $data && 0 < length($data);
	
	my $max_bytes = 160;
	
	my ($m,$n) = (0,length($data));
	my $i = 0;
	# find out total number of qr codes needed
	while(0 < $n - $m){
		die "too many qr codes" unless $i < 16;
		my $k = $max_bytes;
		if($n - $m - $k < 0){
			$k = $n - $m;
		}
		#push(@{$ans},MIME::Base64::encode(pack('C',$i).substr($data,$m,$k)));
		$i += 1;
		$m += $k;
	}
	
	# define sub to write qr code file
	my $writesub = sub{
		my $qr_data = shift;
		my $qr_num = shift;
		qrpng (text => $qr_data, out => $basedir.'/'.$qr_num.'.png');
	};
	
	# split the binary blob here
	($m,$n) = (0,length($data));
	my $j = $i - 1;
	$i = 0;
	while(0 < $n - $m){
		die "too many qr codes" unless $i < 16;
		my $k = $max_bytes;
		if($n - $m - $k < 0){
			$k = $n - $m;
		}
		my $x;
		if($i == 0){
			$x = MIME::Base64::encode(pack('C',$i).pack('C',$j).substr($data,$m,$k));
		}
		else{
			$x = MIME::Base64::encode(pack('C',$i).substr($data,$m,$k));
		}
		$writesub->($x,$i);
		push(@{$array_ref},$x);
		
		$i += 1;
		$m += $k;
	}
	
	return $basedir;
}













1;