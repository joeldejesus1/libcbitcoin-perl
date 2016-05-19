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
struct hd_extended_key_serialized {
	uint8_t data[78];
};


struct hd_extended_key * read_hdkey_from_SV(SV* hdkey_data){
	STRLEN len; //calculated via SvPV
	uint8_t * hdkey_pointer = (uint8_t*) SvPV(hdkey_data,len);
	
	if(len != 78)
		return NULL;
	
	struct hd_extended_key_serialized hdkeyser;
	//hdkeyser->data = calloc(78*sizeof(uint8_t));
	memcpy(hdkeyser.data, hdkey_pointer, 78);
	
	struct hd_extended_key hdkey;
	if(!hd_extended_key_init(&hdkey)){
		//free(hdkeyser->data);
		//free(hdkeyser);
		return NULL;
	}
	
	if(!hd_extended_key_deser(&hdkey, hdkeyser.data,78)){
		//free(hdkeyser->data);
		//free(hdkeyser);
		hd_extended_key_free(&hdkey);
		return NULL;
	}
	//free(hdkeyser->data);
	//free(hdkeyser);
	
	return &hdkey;
}


////////// picocoin

int picocoin_tx_validate (SV* txdata){
	STRLEN len; //calculated via SvPV
	uint8_t * txdata_pointer = (uint8_t*) SvPV(txdata,len);

	
	
	struct const_buffer buf = { txdata_pointer, len };
	
	
	struct bp_tx tx;
	
	bp_tx_init(&tx);
	
	
	if(!deser_bp_tx(&tx,&buf)){
		bp_tx_free(&tx);
		return 0;
	}
	
	if(!bp_tx_valid(&tx)){
		bp_tx_free(&tx);
		return 0;		
	}

	bp_tx_free(&tx);
	return 1;
}

// SV* hdkey,
int picocoin_tx_sign_p2pkh(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType){
	struct hd_extended_key * hdkey = read_hdkey_from_SV(hdkey_data);
	if(hdkey == NULL){
		hd_extended_key_free(hdkey);
		return 0;
	}
	
	uint32_t nIn = (uint32_t) nIn;
	
	STRLEN len; //calculated via SvPV
	uint8_t * txdata_pointer = (uint8_t*) SvPV(txdata,len);
	struct const_buffer buf = { txdata_pointer, len };
	struct bp_tx tx;
	bp_tx_init(&tx);
	// validate the transaction
	if(!deser_bp_tx(&tx,&buf)){
		bp_tx_free(&tx);
		return 0;
	}
	
	if(!bp_tx_valid(&tx)){
		bp_tx_free(&tx);
		return 0;		
	}
	
	// for convenience reasons, change the name
	struct bp_tx * txTo = &tx;
	if (!txTo || !txTo->vin || nIn >= txTo->vin->len)
			return false;
	
	STRLEN len_frompubkey; //calculated via SvPV
	uint8_t * fromPubKey_pointer = (uint8_t*) SvPV(fromPubKey_data,len_frompubkey);
	cstring frompubkey = { fromPubKey_pointer, len_frompubkey};
	
	bu256_t hash;
	bp_tx_sighash(&hash, &frompubkey, txTo, nIn, nHashType);
	
	struct bp_txin *txin = parr_idx(txTo->vin, nIn);
	// find the input
	return 1;
	
	void *sig = NULL;
	size_t siglen = 0;
	if (!bp_sign(&hdkey->key, &hash, sizeof(hash), &sig, &siglen))
		return 0;
	uint8_t ch = (uint8_t) nHashType;
	sig = realloc(sig, siglen + 1);
	memcpy(sig + siglen, &ch, 1);
	siglen++;
	
	// find out how to return the signature...
	
	bp_tx_free(&tx);
	return 1;
}



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

	
int 
picocoin_tx_validate(txdata)
	SV* txdata

int	
picocoin_tx_sign_p2pkh(hdkey_data,fromPubKey_data,txdata,index,HashType)
	SV* hdkey_data
	SV* fromPubKey_data
	SV* txdata
	int index
	int HashType