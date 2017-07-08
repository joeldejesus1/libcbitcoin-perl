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
		return (SV*) picocoin_returnblankSV();
	
	struct hd_extended_key_serialized hdkeyser;
	//hdkeyser->data = calloc(78*sizeof(uint8_t));
	memcpy(hdkeyser.data, hdkey_pointer, 78);
	struct hd_extended_key hdkey;
	hd_extended_key_init(&hdkey);
	
	if(!hd_extended_key_deser(&hdkey, hdkeyser.data,78)){
		//free(hdkeyser->data);
		//free(hdkeyser);
		hd_extended_key_free(&hdkey);
		return (SV*) picocoin_returnblankSV();
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
		return (SV*) picocoin_returnblankSV();
	}
	
	if(!bp_tx_valid(&tx)){
		bp_tx_free(&tx);
		hd_extended_key_free(&hdkey);
		return (SV*) picocoin_returnblankSV();		
	}
	
	// for convenience reasons, change the name
	struct bp_tx * txTo = &tx;
	if (!txTo || !txTo->vin || nIn >= txTo->vin->len){
		bp_tx_free(&tx);
		hd_extended_key_free(&hdkey);
		return (SV*) picocoin_returnblankSV();
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
		return (SV*) picocoin_returnblankSV();		
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
		return (SV*) picocoin_returnblankSV();	
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
	return (SV*) newSVpv(txanswer->str,txanswer->len);
	

}

HV* picocoin_emptytx(HV * rh){
	hv_store(rh, "success", 7, newSViv((int) 0), 0);
	
	return rh;
}

// given a full hdkey, fill in a perl hash with relevant data
HV* picocoin_returntx(HV * rh, const struct bp_tx *tx_arg){
	
	struct bp_tx tx_tmp;
	struct bp_tx *tx = &tx_tmp;
	bp_tx_copy(tx, tx_arg);
	bp_tx_calc_sha256(tx);
	
	hv_store(rh, "success", 7, newSViv((int) 1), 0);
	
	hv_store(rh, "version", 7, newSViv((int)tx->nVersion), 0);
	hv_store(rh, "lockTime", 8, newSViv((int)tx->nLockTime), 0);
	
	
	if(tx->sha256_valid){
		char *hexstr = malloc(32*2*sizeof(char));
		bu256_hex(hexstr,&tx->sha256);
		hv_store(rh, "sha256", 6, newSVpv(hexstr,32*2), 0);
	}
		

	if(tx->vin && tx->vin->len){
		int j;
		struct bp_txin *txin;
		AV* avtxin = (AV *) sv_2mortal ((SV *) newAV ());
		
		for( j=0; j<tx->vin->len; j++){
			//fprintf(stderr,"txin=%d\n",j);
			txin = parr_idx(tx->vin, j);
			
			HV * rhtxin = (HV *) sv_2mortal ((SV *) newHV ());
			
			struct bp_outpt prevout;
	
			//cstring s = { (char *)(out->data), 0, sizeof(out->data) + 1 };
			char prevHash[BU256_STRSZ];
			bu256_hex(prevHash, &txin->prevout.hash);
			
			hv_store( rhtxin, "prevHash", 8, newSVpv( prevHash,  BU256_STRSZ), 0);
			hv_store( rhtxin, "prevIndex", 9, newSViv(txin->prevout.n), 0);
			//fprintf(stderr,"hash[%s]\n",prevHash);
			
			
			
			if(txin->scriptSig && txin->scriptSig->len){
				// scriptSig
				uint8_t * scriptSig = malloc(txin->scriptSig->len * sizeof(uint8_t) );
				memcpy(scriptSig,txin->scriptSig->str,txin->scriptSig->len);
				//SV* ans_sv = newSVpv(answer,length);
				hv_store( rhtxin, "scriptSig", 9, newSVpv( scriptSig,  txin->scriptSig->len), 0);
				
			}
			
			
			av_push(avtxin, newRV((SV *) rhtxin));
			//av_push(avtxin, newSViv(j));
		}
		
		hv_store( rh, "vin", 3, newRV((SV *)avtxin), 0);
	}
	
	if(tx->vout && tx->vout->len){
		int j;
		struct bp_txout *txout;
		AV* avtxout = (AV *) sv_2mortal ((SV *) newAV ());
		
		for( j=0; j<tx->vout->len; j++){
			//fprintf(stderr,"txin=%d\n",j);
			txout = parr_idx(tx->vout, j);
			
			HV * rhtxout = (HV *) sv_2mortal ((SV *) newHV ());
			
	
			hv_store( rhtxout, "value", 5, newSViv( txout->nValue ), 0);
			
			uint8_t *spk = malloc(txout->scriptPubKey->len * sizeof(uint8_t));
			memcpy(spk,txout->scriptPubKey->str,txout->scriptPubKey->len);				
			hv_store( rhtxout, "script", 6, newSVpv(spk,txout->scriptPubKey->len), 0);
					
			
			av_push(avtxout, newRV((SV *) rhtxout));
			//av_push(avtxin, newSViv(j));
		}
		//av_push(avTX, newRV((SV *)avtxout) );
		//bloom_contains(struct bloom *bf, const void *data, size_t data_len);
		hv_store( rh, "vout", 4, newRV((SV *)avtxout), 0);
	}
	
	return rh;
}

HV* picocoin_tx_des(SV* tx_data){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//fprintf(stderr,"in - 1\n");
	
	
	STRLEN len_txdata;
	uint8_t * txdata_pointer = (uint8_t*) SvPV(tx_data,len_txdata);
	struct const_buffer txbuf = { txdata_pointer, len_txdata };
	//fprintf(stderr,"in - 2\n");
	struct bp_tx tx;
	bp_tx_init(&tx);
	//fprintf(stderr,"in - 3\n");
	if(!deser_bp_tx(&tx, &txbuf))
		goto err;
	//fprintf(stderr,"in - 4\n");
	picocoin_returntx(rh,&tx);
	return rh;
	
err:
	//fprintf(stderr,"in - 5\n");
	picocoin_emptytx(rh);
	return rh;
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
	
HV*	
picocoin_tx_des(tx_data)
	SV* tx_data