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





////// extra
struct hd_extended_key_serialized {
	uint8_t data[78];
};



////////// picocoin

int picocoin_tx_validate ( SV* txdata){
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
	//bp_script_verify(txin->scriptSig, txout->scriptPubKey,txTo, nIn, flags, nHashType)
/*	
	unsigned int flags;
	if(sigvalidate == 1){
		flags = SCRIPT_VERIFY_NONE;
	}
	else if(sigvalidate == 2){
		flags = SCRIPT_VERIFY_STRICTENC;
	}
	else if(sigvalidate == 3){
		flags = SCRIPT_VERIFY_P2SH;
	}
	else if(sigvalidate == 4){
		flags = SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_STRICTENC;
	}
	else{
		sighash = 0;
	}
	// bp_script_verify(txin->scriptSig, txout->scriptPubKey,txTo, nIn, flags, nHashType)
	int i;
	for(i=0;i<txTo->vin->len;i++){
		struct bp_txin *txin = parr_idx(txTo->vin, nIn);
		if(!bp_script_verify(txin->scriptSig, txout->scriptPubKey,txTo, nIn, flags, nHashType)){
			i = txTo->vin->len + 1;
		}
	}
	
*/
}


int picocoin_tx_validate_input (
		int index, SV* scriptPubKey_data, SV* txdata,int sigvalidate, int nHashType
){
	// deserialize scriptPubKey (from txFrom->vout)
	STRLEN len_spk; 
	uint8_t * spk_pointer = (uint8_t*) SvPV(scriptPubKey_data,len_spk);
	cstring * scriptPubKey = cstr_new_buf((const void*) spk_pointer, (size_t) len_spk);
	// deserialize transaction
	STRLEN len; //calculated via SvPV
	uint8_t * txdata_pointer = (uint8_t*) SvPV(txdata,len);
	struct const_buffer buf = { txdata_pointer, len };
	struct bp_tx tx;
	bp_tx_init(&tx);

	if(!deser_bp_tx(&tx,&buf)){
		bp_tx_free(&tx);
		cstr_free(scriptPubKey,true);
		return 0;
	}

	if(!bp_tx_valid(&tx)){
		bp_tx_free(&tx);
		cstr_free(scriptPubKey,true);
		return 0;		
	}
	unsigned int nIn = (unsigned int) index;
	
	
	unsigned int flags;
	if(sigvalidate == 1){
		flags = SCRIPT_VERIFY_STRICTENC;
	}
	else if(sigvalidate == 2){
		flags = SCRIPT_VERIFY_P2SH;
	}
	else if(sigvalidate == 3){
		flags = SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_STRICTENC;
	}
	else{
		flags = SCRIPT_VERIFY_NONE;
	}
	// bp_script_verify(txin->scriptSig, txout->scriptPubKey,txTo, nIn, flags, nHashType)
	struct bp_txin *txin = parr_idx(tx.vin, nIn);
	
	
	
	bp_tx_free(&tx);
	cstr_free(scriptPubKey,true);
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
	uint32_t nIn = (uint32_t) nIndex;
	//fprintf(stderr,"Index1=%d\n",nIn);
	STRLEN len; //calculated via SvPV
	uint8_t * txdata_pointer = (uint8_t*) SvPV(txdata,len);
	struct const_buffer buf = { txdata_pointer, len };
	struct bp_tx tx;
	bp_tx_init(&tx);
	// validate the transaction
	if(!deser_bp_tx(&tx,&buf)){
		bp_tx_free(&tx);
		hd_extended_key_free(&hdkey);
		return picocoin_returnblankSV();
	}
	
	if(!bp_tx_valid(&tx)){
		bp_tx_free(&tx);
		hd_extended_key_free(&hdkey);
		return picocoin_returnblankSV();		
	}
	
	// for convenience reasons, change the name
	struct bp_tx * txTo = &tx;
	if (!txTo || !txTo->vin || nIn >= txTo->vin->len){
		bp_tx_free(&tx);
		hd_extended_key_free(&hdkey);
		return picocoin_returnblankSV();
	}

	STRLEN len_frompubkey; //calculated via SvPV
	uint8_t * fromPubKey_pointer = (uint8_t*) SvPV(fromPubKey_data,len_frompubkey);
	cstring frompubkey = { fromPubKey_pointer, len_frompubkey};
	
	bu256_t hash;
	//fprintf(stderr,"Hash Type=%d\n",nHashType);
	bp_tx_sighash(&hash, &frompubkey, txTo, nIn, nHashType);
	
	struct bp_txin *txin = parr_idx(txTo->vin, nIn);
	// find the input
	
	///////////////////////// do signature //////////////////////////
	void *sig = NULL;
	size_t siglen = 0;
	struct bp_key privateKey = hdkey.key;
	
	if (!bp_sign(&hdkey.key, &hash, sizeof(*&hash), &sig, &siglen)){
		bp_tx_free(&tx);
		hd_extended_key_free(&hdkey);
		return picocoin_returnblankSV();		
	}
	//fprintf(stderr,"Index2=%d\n",nIn);

	
	
	uint8_t ch = (uint8_t) nHashType;
	sig = realloc(sig, siglen + 1);
	memcpy(sig + siglen, &ch, 1);
	siglen++;
	
	
	cstring * scriptSig = cstr_new_sz(64);
	bsp_push_data(scriptSig, sig, siglen);
	
	// append public key
	void *pubkey = NULL;
	size_t pk_len = 0;
	if (!bp_pubkey_get(&hdkey.key, &pubkey, &pk_len)){
		free(sig);
		bp_tx_free(&tx);
		free(pubkey);  // is this necessary?
		hd_extended_key_free(&hdkey);
		return picocoin_returnblankSV();	
	}
	
	bsp_push_data(scriptSig, pubkey, pk_len);
	
	if (txin->scriptSig)
		cstr_free(txin->scriptSig, true);
	txin->scriptSig = scriptSig;
	scriptSig = NULL;
	
	cstring *txanswer = cstr_new_sz(bp_tx_ser_size(&tx));
	
	ser_bp_tx(txanswer, &tx);
	
	//sprintf("%s",ans->str);
	hd_extended_key_free(&hdkey);
	bp_tx_free(&tx);
	free(sig);
	free(pubkey);
	return newSVpv(txanswer->str,txanswer->len);
	

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
	
int 
picocoin_tx_validate_input(index,scriptPubKey_data,txdata,sigvalidate,nHashType)
	int index
	SV* scriptPubKey_data
	SV* txdata
	int sigvalidate
	int nHashType

SV*	
picocoin_tx_sign_p2pkh(hdkey_data,fromPubKey_data,txdata,index,HashType)
	SV* hdkey_data
	SV* fromPubKey_data
	SV* txdata
	int index
	int HashType