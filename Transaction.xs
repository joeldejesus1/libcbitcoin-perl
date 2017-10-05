#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <errno.h>

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <assert.h>
#include <ccoin/util.h>
#include <ccoin/key.h>
#include <ccoin/script.h>
#include <ccoin/core.h>
#include <ccoin/hdkeys.h>
#include <ccoin/key.h>
#include <ccoin/serialize.h>
//#include <ccoin/compat.h>

#include "tx.h"




MODULE = CBitcoin::Transaction	PACKAGE = CBitcoin::Transaction


PROTOTYPES: DISABLED

int 
picocoin_tx_validate(txdata)
	SV* txdata
	
int 
picocoin_tx_validate_input(index,scriptPubKey_data,txdata,flags,nHashType,amount)
	int index
	SV* scriptPubKey_data
	SV* txdata
	int flags
	int nHashType
	SV* amount

SV*	
picocoin_tx_sign_p2pkh(hdkey_data,fromPubKey_data,txdata,index,HashType,amount)
	SV* hdkey_data
	SV* fromPubKey_data
	SV* txdata
	int index
	int HashType
	int amount
	
SV*	
picocoin_tx_sign_p2p(hdkey_data,fromPubKey_data,txdata,index,HashType,amount)
	SV* hdkey_data
	SV* fromPubKey_data
	SV* txdata
	int index
	int HashType
	int amount
	
HV*	
picocoin_tx_des(tx_data)
	SV* tx_data