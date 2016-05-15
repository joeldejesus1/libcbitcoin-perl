#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <ccoin/hdkeys.h>

#include <assert.h>
#include <ccoin/base58.h>
#include <openssl/ripemd.h>
#include <openssl/err.h>
#include <ccoin/cstr.h>
#include <ccoin/util.h>

#define MAIN_PUBLIC 0x1EB28804
#define MAIN_PRIVATE 0xE4AD8804

////// extra

struct hd_extended_key_serialized {
	uint8_t data[78];
};

static bool write_ek_ser_pub(struct hd_extended_key_serialized *out,
			     const struct hd_extended_key *ek)
{
	cstring s = { (char *)(out->data), 0, sizeof(out->data) + 1 };
	return hd_extended_key_ser_pub(ek, &s);
}



static bool write_ek_ser_prv(struct hd_extended_key_serialized *out,
			     const struct hd_extended_key *ek)
{
	cstring s = { (char *)(out->data), 0, sizeof(out->data) + 1 };
	return hd_extended_key_ser_priv(ek, &s);
}


static bool read_ek_ser_from_base58(const char *base58,
				    struct hd_extended_key_serialized *out)
{
	cstring *str = base58_decode(base58);
	if (str->len == 82) {
		memcpy(out->data, str->str, 78);
		cstr_free(str, true);
		return true;
	}

	cstr_free(str, true);
	return false;
}


/*
 *   Return success=0 hash (typically indicates failure to deserialize)
 */
HV* picocoin_returnblankhdkey(HV * rh){
	hv_store(rh, "success", 7, newSViv((int) 0), 0);
	return rh;
}
// given a full hdkey, fill in a perl hash with relevant data
HV* picocoin_returnhdkey(HV * rh, const struct hd_extended_key hdkey){

	hv_store(rh, "depth", 5, newSViv( hdkey.depth), 0);
	hv_store(rh, "version", 7, newSViv( hdkey.version), 0);
	hv_store(rh, "index", 5, newSViv( hdkey.index), 0);
	hv_store(rh, "success", 7, newSViv( 1), 0);

	struct hd_extended_key_serialized m_xprv;
	if(write_ek_ser_prv(&m_xprv, &hdkey)){
		hv_store(rh, "serialized private", 18, newSVpv(m_xprv.data,78), 0);
	}
	
	struct hd_extended_key_serialized m_xpub;
	if(write_ek_ser_pub(&m_xpub, &hdkey)){
		hv_store(rh, "serialized public", 17, newSVpv(m_xpub.data,78), 0);
	}

	// cstring* address = bp_pubkey_get_address(const struct bp_key *key, unsigned char addrtype);
	
	// get the public key
	void *pubkey = NULL;
	size_t pk_len = 0;
	
	if(bp_pubkey_get(&hdkey.key, &pubkey, &pk_len)){
		hv_store(rh, "public key", 10, newSVpv(pubkey,pk_len), 0);
		
		uint8_t *pk2 = malloc(pk_len * sizeof(uint8_t));
		memcpy(pk2,pubkey,pk_len);
		// don't create address here because we need the network bytes
		// do the network bytes in perl code, it is more convenient
		uint8_t md160[RIPEMD160_DIGEST_LENGTH];
		bu_Hash160(md160, pk2, pk_len);
		free(pk2);
		hv_store(rh, "ripemdHASH160", 13, newSVpv(md160,RIPEMD160_DIGEST_LENGTH), 0);
	}
	
	//hd_extended_key_free(&hdkey);
	return rh;
}


//////////////// picocoin - load from base58 /////////////////
HV* picocoin_newhdkey(SV* base58x){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	STRLEN len; //calculated via SvPV
	char * base58xPointer = (char*) SvPV(base58x,len);
	
	struct hd_extended_key_serialized hdkeyser;
	if(!read_ek_ser_from_base58(base58xPointer,&hdkeyser)){
		return picocoin_returnblankhdkey(rh);
	}
	struct hd_extended_key hdkey;
	if(!hd_extended_key_init(&hdkey)){
		return picocoin_returnblankhdkey(rh);
	}	
	if(!hd_extended_key_deser(&hdkey, hdkeyser.data,78)){
		return picocoin_returnblankhdkey(rh);
	}
	
	picocoin_returnhdkey(rh,hdkey);
	hd_extended_key_free(&hdkey);

	return rh;
}

HV* picocoin_generatehdkeymaster(SV* seed){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
		
	STRLEN len; //calculated via SvPV
	uint8_t * seed_raw = (uint8_t*) SvPV(seed,len);
	
	struct hd_extended_key hdkey;
	if(!hd_extended_key_init(&hdkey)){
		return picocoin_returnblankhdkey(rh);
	}
	
	if(!hd_extended_key_generate_master(&hdkey, seed_raw, len)){
		return picocoin_returnblankhdkey(rh);
	}
	picocoin_returnhdkey(rh,hdkey);
	hd_extended_key_free(&hdkey);
	return rh;
}


HV* picocoin_generatehdkeychild(SV* xpriv, int child_index){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//static const char s_tv1_m_xpub3[] = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";
	STRLEN len; //calculated via SvPV
	uint8_t * xpriv_msg = (uint8_t*) SvPV(xpriv,len);
	if(len != 78){
		return picocoin_returnblankhdkey(rh);
	}
	
	struct hd_extended_key hdkey;
	if(!hd_extended_key_init(&hdkey)){
		return picocoin_returnblankhdkey(rh);
	}
	if(!hd_extended_key_deser(&hdkey,xpriv_msg,len)){
		return picocoin_returnblankhdkey(rh);
	}
	
	// create the child key
	struct hd_extended_key childhdkey;
	if(!hd_extended_key_init(&childhdkey)){
		return picocoin_returnblankhdkey(rh);
	}
	if(!hd_extended_key_generate_child(&hdkey,(uint32_t) child_index,&childhdkey)){
		return picocoin_returnblankhdkey(rh);
	}
	
	// populate the hash with data from child key
	picocoin_returnhdkey(rh,childhdkey);
	hd_extended_key_free(&hdkey);
	hd_extended_key_free(&childhdkey);
	return rh;
}


MODULE = CBitcoin::CBHD	PACKAGE = CBitcoin::CBHD	


PROTOTYPES: DISABLED

HV*
picocoin_newhdkey(base58x)
	SV* base58x
	
HV*
picocoin_generatehdkeymaster(seed)
	SV* seed

HV*
picocoin_generatehdkeychild(xpriv,child_index)
	SV* xpriv
	int child_index
