#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <ccoin/hdkeys.h>

#include <assert.h>
#include <ccoin/base58.h>
#include <openssl/err.h>
#include <ccoin/cstr.h>

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

/*
 *   Return success=0 hash (typically indicates failure to deserialize)
 */
HV* picocoin_returnblankhdkey(HV * rh){
	hv_store(rh, "success", 7, newSViv((int) 0), 0);
	return rh;
}


//////////////// picocoin /////////////////
HV* picocoin_newhdkey(char* s_tv1_m_xpub){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	struct hd_extended_key hdkey;
	cstring *tv1data = base58_decode(s_tv1_m_xpub);
	if(!hd_extended_key_deser(&hdkey, tv1data->str, tv1data->len)){
		cstr_free(tv1data, true);
		return picocoin_returnblankhdkey(rh);
	}
	cstr_free(tv1data, true);
	
	
	// struct bp_key key = hdkey.key;
	cstring *address = bp_pubkey_get_address(&(hdkey.key), MAIN_PUBLIC);
	hv_store(rh, "address", 7, newSVpv( address->str, address->len ), 0);
	
	//hd_extended_key_ser_pub(const struct hd_extended_key *ek, cstring *s)
	

	hv_store(rh, "depth", 5, newSViv( hdkey.depth), 0);
	hv_store(rh, "version", 7, newSViv(hdkey.version), 0);
	hv_store(rh, "index", 5, newSViv( hdkey.index), 0);
	hv_store(rh, "success", 7, newSViv( 1), 0);

	

	// integer: hv_store(rh, "nonce", 5, newSViv(x->nonce), 0);
	// scalar: hv_store(rh, "hash", 4, newSVpv(hash,32), 0); 
	hd_extended_key_free(&hdkey);

	return rh;
}

HV* picocoin_generatehdkeymaster(char* seed){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
		
	struct hd_extended_key hdkey;
	if(!hd_extended_key_init(&hdkey)){
		return picocoin_returnblankhdkey(rh);
	}
	
	if(!hd_extended_key_generate_master(&hdkey, seed, sizeof(seed))){
		return picocoin_returnblankhdkey(rh);
	}
	hv_store(rh, "depth", 5, newSViv( hdkey.depth), 0);
	hv_store(rh, "version", 7, newSViv( hdkey.version), 0);
	hv_store(rh, "index", 5, newSViv( hdkey.index), 0);
	hv_store(rh, "success", 7, newSViv( 1), 0);

	struct hd_extended_key_serialized m_xprv;
	if(write_ek_ser_prv(&m_xprv, &hdkey)){
		hv_store(rh, "serialized private", 18, newSVpv(m_xprv.data,78), 0);
	}
	
	struct hd_extended_key_serialized m_xpub;
	if(write_ek_ser_pub(&m_xprv, &hdkey)){
		hv_store(rh, "serialized public", 17, newSVpv(m_xpub.data,78), 0);
	}
	
	// public key: static void print_ek_public(const struct hd_extended_key *ek)
	
	
	// integer: hv_store(rh, "nonce", 5, newSViv(x->nonce), 0);
	// scalar: hv_store(rh, "hash", 4, newSVpv(hash,32), 0); 
	hd_extended_key_free(&hdkey);

	return rh;
}
/*
HV* picocoin_generatehdkeychild(char* xpriv, int child_index){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//static const char s_tv1_m_xpub3[] = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";
		
	struct hd_extended_key childhdkey;
	struct hd_extended_key hdkey;
	
	bool works = hd_extended_key_init(&childhkkey);
	
	
	if(works)
		works = hd_extended_key_generate_master(&hdkey, seed, sizeof(seed));

	if(works){
		hv_store(rh, "depth", 5, newSViv( hdkey.depth), 0);
		hv_store(rh, "version", 7, newSViv( hdkey.version), 0);
		hv_store(rh, "index", 5, newSViv( hdkey.index), 0);
		hv_store(rh, "success", 7, newSViv( 1), 0);
		// hd_extended_key_ser_pub(, );
	}
	else{
		hv_store(rh, "success", 7, newSViv( 0), 0);
	}
	// integer: hv_store(rh, "nonce", 5, newSViv(x->nonce), 0);
	// scalar: hv_store(rh, "hash", 4, newSVpv(hash,32), 0); 


	return rh;
}
*/

MODULE = CBitcoin::CBHD	PACKAGE = CBitcoin::CBHD	


PROTOTYPES: DISABLED

HV*
picocoin_newhdkey(s_tv1_m_xpub)
	char* s_tv1_m_xpub
	
HV*
picocoin_generatehdkeymaster(seed)
	char* seed
	