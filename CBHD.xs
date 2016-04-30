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

#define MAIN_PUBLIC 0x1EB28804
#define MAIN_PRIVATE 0xE4AD8804



//////////////// picocoin /////////////////
HV* picocoin_newhdkey(char* s_tv1_m_xpub){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//static const char s_tv1_m_xpub3[] = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";
	
	struct hd_extended_key hdkey;
	cstring *tv1data = base58_decode(s_tv1_m_xpub);
	bool works = hd_extended_key_deser(&hdkey, tv1data->str, tv1data->len);
	cstr_free(tv1data, true);

	if(works){
		hv_store(rh, "depth", 5, newSViv( hdkey.depth), 0);
		hv_store(rh, "version", 7, newSViv((int) hdkey.version), 0);
		hv_store(rh, "index", 5, newSViv( hdkey.index), 0);
		hv_store(rh, "success", 7, newSViv((int) 1), 0);
		// hd_extended_key_ser_pub(, );
	}
	else{
		hv_store(rh, "success", 7, newSViv((int) 0), 0);
	}
	// integer: hv_store(rh, "nonce", 5, newSViv(x->nonce), 0);
	// scalar: hv_store(rh, "hash", 4, newSVpv(hash,32), 0); 


	return rh;
}

HV* picocoin_generatehdkeymaster(char* seed){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//static const char s_tv1_m_xpub3[] = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";
		
	struct hd_extended_key hdkey;
	bool works = hd_extended_key_init(&hdkey);
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

HV* picocoin_generatehdkeychild(char* xpriv, int child_index){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//static const char s_tv1_m_xpub3[] = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";
		
	struct hd_extended_key childhdkey;
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


MODULE = CBitcoin::CBHD	PACKAGE = CBitcoin::CBHD	


PROTOTYPES: DISABLED

HV*
picocoin_newhdkey(s_tv1_m_xpub)
	char* s_tv1_m_xpub
	
HV*
picocoin_generatehdkeymaster(seed)
	char* seed
	
HV*
picocoin_generatehdkeychild(xpriv,child_index)
	char* xpriv
	int	child_index	