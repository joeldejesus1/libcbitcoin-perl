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


SV* picocoin_tx_sign_p2pkh(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType){
	
	////////////// import hdkey ////////////////////////////
	STRLEN len_hdkey; //calculated via SvPV
	uint8_t * hdkey_pointer = (uint8_t*) SvPV(hdkey_data,len_hdkey);
	if(len_hdkey != 78)
		return picocoin_returnblankSV();
	struct hd_extended_key_serialized hdkeyser;
	//hdkeyser->data = calloc(78*sizeof(uint8_t));
	memcpy(hdkeyser.data, hdkey_pointer, 78);
	struct hd_extended_key hdkey;
	if(!hd_extended_key_init(&hdkey)){
		return picocoin_returnblankSV();
	}
	if(!hd_extended_key_deser(&hdkey, hdkeyser.data,78)){
		//free(hdkeyser->data);
		//free(hdkeyser);
		hd_extended_key_free(&hdkey);
		return picocoin_returnblankSV();
	}
	
	///////////// import tx //////////////////
	uint32_t nIn = (uint32_t) nIn;
	
	STRLEN len; //calculated via SvPV
	uint8_t * txdata_pointer = (uint8_t*) SvPV(txdata,len);
	struct const_buffer buf = { txdata_pointer, len };
	struct bp_tx tx;
	bp_tx_init(&tx);
	// validate the transaction
	if(!deser_bp_tx(&tx,&buf)){
		bp_tx_free(&tx);
		return picocoin_returnblankSV();
	}
	
	if(!bp_tx_valid(&tx)){
		bp_tx_free(&tx);
		return picocoin_returnblankSV();		
	}
	
	// for convenience reasons, change the name
	struct bp_tx * txTo = &tx;
	if (!txTo || !txTo->vin || nIn >= txTo->vin->len)
			return picocoin_returnblankSV();
	
	STRLEN len_frompubkey; //calculated via SvPV
	uint8_t * fromPubKey_pointer = (uint8_t*) SvPV(fromPubKey_data,len_frompubkey);
	cstring frompubkey = { fromPubKey_pointer, len_frompubkey};
	
	bu256_t hash;
	bp_tx_sighash(&hash, &frompubkey, txTo, nIn, nHashType);
	
	struct bp_txin *txin = parr_idx(txTo->vin, nIn);
	// find the input
	
	///////////////////////// do signature //////////////////////////
	void *sig = NULL;
	size_t siglen = 0;
	struct bp_key privateKey = hdkey.key;
	
	if (!bp_sign(&hdkey.key, &hash, sizeof(*&hash), &sig, &siglen))
		return picocoin_returnblankSV();
	
	
	uint8_t ch = (uint8_t) nHashType;
	sig = realloc(sig, siglen + 1);
	memcpy(sig + siglen, &ch, 1);
	siglen++;
	//fprintf(stderr,"hello(%d)(%s)",siglen,sig);
	
	cstring * scriptSig = cstr_new_sz(0);
	bsp_push_data(scriptSig, sig, siglen);
	//sprintf("%s",ans->str);
	hd_extended_key_free(&hdkey);
	bp_tx_free(&tx);
	free(sig);
	return newSVpv(scriptSig->str,scriptSig->len);
	

}

/*
 *  scriptPubKey is the script in the previous transaction output.
 *  scriptSig is the script that gets ripemd hash160's into a p2sh (need this to make signature)
 *  outpoint = 32 byte tx hash followed by 4 byte uint32_t tx index
 */




MODULE = CBitcoin::Transaction	PACKAGE = CBitcoin::Transaction


PROTOTYPES: DISABLED


	
int 
picocoin_tx_validate(txdata)
	SV* txdata

SV*	
picocoin_tx_sign_p2pkh(hdkey_data,fromPubKey_data,txdata,index,HashType)
	SV* hdkey_data
	SV* fromPubKey_data
	SV* txdata
	int index
	int HashType