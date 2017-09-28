#include "uahf.h"
#include "standard.h"


/*
void uahf_bp_tx_sighash(bu256_t *hash, const cstring *scriptCode,
		   const struct bp_tx *txTo, unsigned int nIn,
		   int nHashType)
{
	if (nIn >= txTo->vin->len) {
		//  nIn out of range
		bu256_set_u64(hash, 1);
		return;
	}

	// Check for invalid use of SIGHASH_SINGLE
	if ((nHashType & 0x1f) == SIGHASH_SINGLE) {
		if (nIn >= txTo->vout->len) {
			//  nOut out of range
			bu256_set_u64(hash, 1);
			return;
		}
	}

	cstring *s = cstr_new_sz(512);

	// Serialize only the necessary parts of the transaction being signed
	bp_tx_sigserializer(s, scriptCode, txTo, nIn, nHashType);

	ser_s32(s, nHashType);
	bu_Hash((unsigned char *) hash, s->str, s->len);

	cstr_free(s, true);
}
*/

SV* uahf_picocoin_tx_sign_p2pkh(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType){

	////////////// import hdkey ////////////////////////////
	STRLEN len_hdkey; //calculated via SvPV
	uint8_t * hdkey_pointer = (uint8_t*) SvPV(hdkey_data,len_hdkey);
	if(len_hdkey != 78)
		return picocoin_returnblankSV();

	struct hd_extended_key_serialized hdkeyser;
	//hdkeyser->data = calloc(78*sizeof(uint8_t));
	memcpy(hdkeyser.data, hdkey_pointer, 78);
	struct hd_extended_key hdkey;
	hd_extended_key_init(&hdkey);

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

SV* uahf_picocoin_tx_sign_p2p(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType){

	////////////// import hdkey ////////////////////////////
	STRLEN len_hdkey; //calculated via SvPV
	uint8_t * hdkey_pointer = (uint8_t*) SvPV(hdkey_data,len_hdkey);
	if(len_hdkey != 78)
		return picocoin_returnblankSV();

	struct hd_extended_key_serialized hdkeyser;
	//hdkeyser->data = calloc(78*sizeof(uint8_t));
	memcpy(hdkeyser.data, hdkey_pointer, 78);
	struct hd_extended_key hdkey;
	hd_extended_key_init(&hdkey);

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

	uahf_bp_tx_sighash(&hash, &frompubkey, txTo, nIn, nHashType,0);

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

	// append signature
	cstring * scriptSig = cstr_new_sz(64);
	bsp_push_data(scriptSig, sig, siglen);

	// append public key
	//void *pubkey = NULL;
	/*size_t pk_len = 0;
	if (!bp_pubkey_get(&hdkey.key, &pubkey, &pk_len)){
		free(sig);
		bp_tx_free(&tx);
		free(pubkey);  // is this necessary?
		hd_extended_key_free(&hdkey);
		return picocoin_returnblankSV();
	}*/
	//bsp_push_data(scriptSig, pubkey, pk_len);

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
	//free(pubkey);
	return newSVpv(txanswer->str,txanswer->len);


}



// extra functions copied from picocoin library

