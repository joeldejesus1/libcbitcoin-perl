#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <errno.h>

#include <assert.h>
#include <openssl/ripemd.h>
#include <openssl/sha.h>
#include <openssl/err.h>
#include <ccoin/cstr.h>
#include <ccoin/util.h>
#include <ccoin/hdkeys.h>
#include <ccoin/base58.h>

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

void *KDF1_SHA256(const void *in, size_t inlen, void *out, size_t *outlen)
{
    if (*outlen < SHA256_DIGEST_LENGTH)
        return NULL;
    else
        *outlen = SHA256_DIGEST_LENGTH;
    return SHA256(in, inlen, out);
}


/*
 *   Return success=0 hash (typically indicates failure to deserialize)
 */

// get counter party's publickey, create ephemeral key, and 
SV* picocoin_ecdh_encrypt(SV* publickey){
	STRLEN len; //calculated via SvPV
	uint8_t * pubkey = (uint8_t*) SvPV(publickey,len);
	size_t pk_len = (size_t) len;

	if(pk_len <= 0){
		return &PL_sv_undef;
	}

	struct bp_key *bp_pubkey = malloc(sizeof(struct bp_key));
	if(!bp_key_init(bp_pubkey)){
		bp_key_free(bp_pubkey);
		return &PL_sv_undef;
	}

	if(!bp_pubkey_set(bp_pubkey, pubkey, pk_len)){
		bp_key_free(bp_pubkey);
		return &PL_sv_undef;
	}
	//fprintf(stderr,"part 1\n");
	// create ephemeral key
	EC_KEY *ephemeral_key = NULL;
	const EC_GROUP *group = NULL;
	group = EC_KEY_get0_group(bp_pubkey->k);
	ephemeral_key = EC_KEY_new();
	EC_KEY_set_group(ephemeral_key, group);
	EC_KEY_generate_key(ephemeral_key);  
	//fprintf(stderr,"part 2\n");
	
	
	// make an array big enough to handle both uncompressed and compressed public keys 
	uint8_t ephbuf[100];
	
	// POINT_CONVERSION_COMPRESSED, to get 33 bytes instead of the uncompressed 65 bytes
	size_t ephpub_len = EC_POINT_point2oct(group,EC_KEY_get0_public_key(ephemeral_key)
		,POINT_CONVERSION_COMPRESSED, ephbuf, 100, NULL
	);
	if(ephpub_len <= 0){
		bp_key_free(bp_pubkey);
		EC_KEY_free(ephemeral_key);
		return &PL_sv_undef;
	}
	
	
	// create buffer to hold the shared secret and the public part of the ephemeral key
	uint8_t *buf = malloc((SHA256_DIGEST_LENGTH + ephpub_len) * sizeof(uint8_t));
	memcpy(&buf[SHA256_DIGEST_LENGTH],ephbuf,ephpub_len);
	
	// calculate the shared secret with the ephemeral private key and recepient public key
	ECDH_compute_key(&buf[0], SHA256_DIGEST_LENGTH, EC_KEY_get0_public_key(bp_pubkey->k), ephemeral_key, KDF1_SHA256);
	
	bp_key_free(bp_pubkey);
	EC_KEY_free(ephemeral_key);
	
	return (SV* ) newSVpv(buf,SHA256_DIGEST_LENGTH + ephpub_len);
}



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
	
	uint8_t *privkey = malloc(33 * sizeof(uint8_t));
	if(bp_key_secret_get(privkey, 32, &hdkey.key)){
		privkey[32] = 0x01;
		hv_store(rh, "private key", 11, newSVpv(privkey,33), 0);
		//fprintf(stderr,"pk length=%d\n",prk_len);
	}
	else{
		free(privkey);
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

	//fprintf(stderr,"Child index:(%lu)\n",(uint32_t) child_index);
	
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
	
SV*
picocoin_ecdh_encrypt(publickey)
	SV* publickey
