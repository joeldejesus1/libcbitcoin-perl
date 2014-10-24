program_NAME := libperl-cbitcoin


.PHONY: all clean distclean

all: build-all

build-all: cbhd-build script-build transaction-build transactioninput-build transactionoutput-build

cbhd-build:
	cd build/CBitcoin/CBHD && make 
script-build:
	cd build/CBitcoin/Script && make
transaction-build:
	cd build/CBitcoin/Transaction && make
transactioninput-build:
	cd build/CBitcoin/TransactionInput && make
transactionoutput-build:
	cd build/CBitcoin/TransactionOutput && make

install: cbhd-install script-install transaction-install transactioninput-install transactionoutput-install

cbhd-install:
	cd build/CBitcoin/CBHD && make install 
script-install:
	cd build/CBitcoin/Script && make install
transaction-install:
	cd build/CBitcoin/Transaction && make install
transactioninput-install:
	cd build/CBitcoin/TransactionInput && make install
transactionoutput-install:
	cd build/CBitcoin/TransactionOutput && make install



clean: clean-all
clean-all: cbhd-clean script-clean transaction-clean transactioninput-clean transactionoutput-clean
cbhd-clean:
	cd build/CBitcoin/CBHD && make clean && rm Makefile.old
script-clean:
	cd build/CBitcoin/Script && make clean && rm Makefile.old
transaction-clean:
	cd build/CBitcoin/Transaction && make clean && rm Makefile.old
transactioninput-clean:
	cd build/CBitcoin/TransactionInput && make clean && rm Makefile.old
transactionoutput-clean:
	cd build/CBitcoin/TransactionOutput && make clean && rm Makefile.old


distclean: clean

