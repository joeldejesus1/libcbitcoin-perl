use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;
my %options = %{
{
  'TYPEMAPS' => [],
  'NAME' => 'CBitcoin::CBHD',
  'INC' => '/usr/include',
  'LIBS' => ['-lcbitcoin']
  #,'MYEXTLIB' => '/usr/lib/libcbitcoin.so '
  ,'VERSION' => '0.01'
}
};
WriteMakefile(%options);

# Remove the Makefile dependency. Causes problems on a few systems.
sub MY::makefile { '' }
