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
//#include <ccoin/compat.h>

////// extra


SV* hello (SV* hdkeydata){
	STRLEN len; //calculated via SvPV
	uint8_t * hdkeydata_pointer = (uint8_t*) SvPV(hdkeydata,len);
	
	struct bp_keystore *ks;
	bkeys_init(ks);
	
	struct hd_extended_key *hdkey;
	hd_extended_key_init(hdkey);
	if(!hd_extended_key_deser(hdkey, hdkeydata_pointer,len)){
		hd_extended_key_free(hdkey);
		bkeys_free(ks);
		// returnblank defined in Script.xs
		return picocoin_returnblankSV();
	}
	
	if(!bkeys_add(ks, &hdkey->key)){
		hd_extended_key_free(hdkey);
		bkeys_free(ks);
		return picocoin_returnblankSV();
	}
	
	bkeys_free(ks);
}


SV* picocoin_generate_rawtx(SV* txinputs_array, SV* txoutputs_array){
	int n;
	
	
	I32 txinputs_length = 0;
    if (
    	(! SvROK(txinputs_array))
    	|| (SvTYPE(SvRV(txinputs_array)) != SVt_PVAV)
    	|| ((txinputs_length = av_len((AV *)SvRV(txinputs_array))) < 0)
    ){
        return picocoin_returnblankSV();
    }
    
	for (n=0; n<=txinputs_length; n++) {
		STRLEN l;

		uint8_t * fn = SvPV (*av_fetch ((AV *) SvRV (txinputs_array), n, 0), l);
		
		// fn    length
		
	}
	
	I32 txoutputs_length = 0;
    if (
    	(! SvROK(txoutputs_array))
    	|| (SvTYPE(SvRV(txoutputs_array)) != SVt_PVAV)
    	|| ((txoutputs_length = av_len((AV *)SvRV(txoutputs_array))) < 0)
    ){
        return picocoin_returnblankSV();
    }
    //uint8_t** multisig = (uint8_t**)malloc(nKeysInt * sizeof(uint8_t*));
    
	for (n=0; n<=txoutputs_length; n++) {
		STRLEN l;

		uint8_t * fn = SvPV (*av_fetch ((AV *) SvRV (txoutputs_array), n, 0), l);
		
		// fn    length
		
	}
    
}



int dummy5(int x) {
	return x;
}

/*
 *  scriptPubKey is the script in the previous transaction output.
 *  scriptSig is the script that gets ripemd hash160's into a p2sh (need this to make signature)
 *  outpoint = 32 byte tx hash followed by 4 byte uint32_t tx index
 */




MODULE = CBitcoin::Transaction	PACKAGE = CBitcoin::Transaction


PROTOTYPES: DISABLED

int
dummy5(x)
	int x
	
SV*
picocoin_generate_rawtx(ins,outs)
	SV* ins
	SV* outs
