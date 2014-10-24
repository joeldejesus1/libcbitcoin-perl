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

clean: clean-all

clean-all: cbhd-clean script-clean transaction-clean transactioninput-clean transactionoutput-clean

cbhd-clean:
	cd build/CBitcoin/CBHD && make clean
script-clean:
	cd build/CBitcoin/Script && make clean
transaction-clean:
	cd build/CBitcoin/Transaction && make clean
transactioninput-clean:
	cd build/CBitcoin/TransactionInput && make clean
transactionoutput-clean:
	cd build/CBitcoin/TransactionOutput && make clean


distclean: clean
