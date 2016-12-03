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
#include <ccoin/buffer.h>
#include <ccoin/serialize.h>

#define MAIN_PUBLIC 0x1EB28804
#define MAIN_PRIVATE 0xE4AD8804


#define BIP32_MAIN_PUBLIC 0x0488B21E
#define BIP32_MAIN_PRIVATE 0x0488ADE4
#define BIP32_TEST_PUBLIC 0x043587CF
#define BIP32_TEST_PRIVATE 0x04358394

//#include "CBitcoin.h"

////// extra

struct hd_extended_key_serialized {
	uint8_t data[78];
};

static void hd_extended_key_ser_base(const struct hd_extended_key *ek,
				     cstring *s, uint32_t version)
{
	ser_u32(s, htobe32(version));
	ser_bytes(s, &ek->depth, 1);
	ser_bytes(s, &ek->parent_fingerprint, 4);
	ser_u32(s, htobe32(ek->index));
	ser_bytes(s, &ek->chaincode, 32);
}

static bool write_ek_ser_pub(struct hd_extended_key_serialized *out,
			     const struct hd_extended_key *ek)
{
	cstring s = { (uint8_t *)(out->data), 0, sizeof(out->data) + 1 };
	//if(!hd_extended_key_ser_pub(ek, &s)){
	//	return false;
	//}
	uint32_t version = 0;
	if(ek->version == BIP32_MAIN_PUBLIC || ek->version == BIP32_MAIN_PRIVATE ){
	
		version = BIP32_MAIN_PUBLIC;
	}
	else if(ek->version == BIP32_TEST_PUBLIC || ek->version == BIP32_TEST_PRIVATE ){
	
		version = BIP32_TEST_PUBLIC;
	}
	else{
		return false;
	}
	
	
	hd_extended_key_ser_base(ek, &s, version);

	void *pub = NULL;
	size_t pub_len = 0;
	if (bp_pubkey_get(&ek->key, &pub, &pub_len)) {
		if (33 == pub_len) {
			ser_bytes(&s, pub, 33);
			free(pub);
			return true;
		}
	}
	free(pub);
	return false;

}



static bool write_ek_ser_prv(struct hd_extended_key_serialized *out,
			     const struct hd_extended_key *ek)
{
	cstring s = { (char *)(out->data), 0, sizeof(out->data) + 1 };
	//return hd_extended_key_ser_priv(ek, &s);
	uint32_t version = 0;
	if(ek->version == BIP32_MAIN_PRIVATE ){
		
		version = BIP32_MAIN_PRIVATE;
	}
	else if(ek->version == BIP32_TEST_PRIVATE ){
		
		version = BIP32_TEST_PRIVATE;
	}
	else{
		return false;
	}
	
	hd_extended_key_ser_base(ek, &s, version);

	const uint8_t zero = 0;
	ser_bytes(&s, &zero, 1);
	return bp_key_secret_get(s.str + s.len, 32, &ek->key);
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


uint8_t* sharedsecret(const EC_GROUP* group,const EC_POINT * ep_pub, const BIGNUM *bn_priv, size_t * sec_len){
	
	int field_size = EC_GROUP_get_degree(group);
	
	BN_CTX *ctx = BN_CTX_new();
	EC_POINT* sspoint = EC_POINT_new(group);
	EC_POINT_mul(group,sspoint,NULL,ep_pub,bn_priv,ctx);
	
	BIGNUM *x = BN_new();
	BIGNUM *y = BN_new();

	if(EC_POINT_get_affine_coordinates_GFp(group, sspoint, x, y, NULL)){
		*sec_len = BN_num_bytes(x);
		uint8_t * buf = (uint8_t *) OPENSSL_malloc(*sec_len);
		BN_bn2bin(x,buf);
		BN_CTX_free(ctx);
		BN_free(x);
		BN_free(y);
		EC_POINT_free(sspoint);
		
		return buf;
	}
	else{
		BN_CTX_free(ctx);
		BN_free(x);
		BN_free(y);
		EC_POINT_free(sspoint);
		sec_len = 0;
		return NULL;
	}
}


/*
 * Given a string/offset, create a new private key and public key
 */
SV* picocoin_offset_private_key(SV* privatekey,SV* offset) {
	SV* returnSV = (SV*)&PL_sv_undef;
	
	STRLEN len; //calculated via SvPV
	uint8_t * privkey = (uint8_t*) SvPV(privatekey,len);
	if(len < 32){
		return returnSV;
	}
	// load in the private key
	struct bp_key *bp_privkey = malloc(sizeof(struct bp_key));
	if(!bp_key_init(bp_privkey)){
		bp_key_free(bp_privkey);
		return returnSV;
	}
	if(!bp_key_secret_set(bp_privkey, privkey, 32)){
		bp_key_free(bp_privkey);
		return returnSV;
	}
	
	BIGNUM *privkey_bn = EC_KEY_get0_private_key(bp_privkey->k);
	//BN_free(privkey_bn);
	
	// now we have bp_privkey, get a 256 bit number for the offset?
	uint8_t * offset_privkey = (uint8_t*) SvPV(offset,len);
	if(len <= 0){
		bp_key_free(bp_privkey);
		return returnSV;
	}
	uint8_t offset_hash[SHA256_DIGEST_LENGTH];
	SHA256_CTX sha256;
	SHA256_Init(&sha256);
	SHA256_Update(&sha256, offset_privkey, len);
	SHA256_Final(offset_hash, &sha256);
	
	BIGNUM *offsetbn = BN_bin2bn(offset_hash, 32, BN_new());
	
	BIGNUM *newprivbn = BN_new();
	
	BN_CTX *ctx = BN_CTX_new();
	
	
	
	EC_GROUP *group = EC_KEY_get0_group(bp_privkey->k);
	
	
	BIGNUM * order = BN_new();
	EC_GROUP_get_order(group, order, ctx);
	
	
	struct bp_key *bp_newprivkey = malloc(sizeof(struct bp_key));
	EC_POINT * pub_key = EC_POINT_new(group);
	
	// calculate the new private key
	if(!BN_mod_add(newprivbn, privkey_bn, offsetbn, order, ctx)){
		goto err;
	}
	
	uint8_t to[200];
	int to_len = BN_bn2bin(newprivbn, to);
	if(to_len <= 0){
		goto err;		
	}
	
	// bp_key_generate
	if(!bp_key_init(bp_newprivkey)){
		goto err;
	}
	if(!bp_key_secret_set(bp_newprivkey, to, to_len)){
		goto err;
	}
	
	
	if (!EC_POINT_mul(group, pub_key, newprivbn, NULL, NULL, ctx)){
		goto err;
	}
		
	uint8_t ephbuf[500];
	size_t ephpub_len = EC_POINT_point2oct(group,pub_key
		,POINT_CONVERSION_COMPRESSED, ephbuf, 500, NULL
	);

	uint8_t * to2 = malloc((to_len + ephpub_len) * sizeof(uint8_t));
	memcpy(&to2[0],to,to_len);
	memcpy(&to2[to_len],ephbuf,ephpub_len);
	
	returnSV = (SV *) newSVpv(to2,(to_len + ephpub_len));
	
err:
	bp_key_free(bp_privkey);
	BN_free(offsetbn);
	BN_free(newprivbn);
	BN_CTX_free(ctx);
	EC_POINT_free(pub_key);
	BN_free(order);
	//EC_GROUP_free(group);
	return returnSV;
}

/*
 * Given a string/offset, create a new public key
 */
SV* picocoin_offset_public_key(SV* publickey,SV* offset) {
	SV* returnSV = (SV*)&PL_sv_undef;
	
	STRLEN len; //calculated via SvPV
	
	uint8_t * pubkey = (uint8_t*) SvPV(publickey,len);
	size_t pubkey_len = len;
	if(pubkey_len < 32){
		return returnSV;
	}
	// load in the private key
	struct bp_key *bp_pubkey = malloc(sizeof(struct bp_key));
	if(!bp_key_init(bp_pubkey)){
		bp_key_free(bp_pubkey);
		return returnSV;
	}

	
	if(!bp_pubkey_set(bp_pubkey, pubkey, pubkey_len)){
		bp_key_free(bp_pubkey);
		return returnSV;
	}


	const EC_POINT *pubkey_point = EC_KEY_get0_public_key(bp_pubkey->k);
	
	// now we have bp_privkey, get a 256 bit number for the offset?
	uint8_t * offset_privkey = (uint8_t*) SvPV(offset,len);
	if(len <= 0){
		bp_key_free(bp_pubkey);
		return returnSV;
	}
	uint8_t offset_hash[SHA256_DIGEST_LENGTH];
	memset(offset_hash, 0, SHA256_DIGEST_LENGTH);
	SHA256_CTX sha256;
	SHA256_Init(&sha256);
	SHA256_Update(&sha256, offset_privkey, len);
	SHA256_Final(offset_hash, &sha256);
	
	BIGNUM *offsetbn = BN_bin2bn(offset_hash, 32, BN_new());

	
	
	BN_CTX *ctx = BN_CTX_new();	
	EC_GROUP *group = EC_KEY_get0_group(bp_pubkey->k);
	
	EC_POINT *offsetpub = EC_POINT_new(group);
	EC_POINT *newpub = EC_POINT_new(group);
	

	
	// with the offsetbn as a private key, get the public key.
	if (!EC_POINT_mul(group, offsetpub, offsetbn, NULL, NULL, ctx)){
		goto err;
	}
	
	if(!EC_POINT_add(group, newpub, pubkey_point, offsetpub, ctx)){
		goto err;
	}
	
	uint8_t ephbuf[500];
	memset(ephbuf, 0, 500);
	size_t ephpub_len = EC_POINT_point2oct(group,newpub
		,POINT_CONVERSION_COMPRESSED, ephbuf, 500, NULL
	);
	
	
	uint8_t * newpubout = malloc(ephpub_len * sizeof(uint8_t));
	memcpy(newpubout,ephbuf,ephpub_len);
	
	returnSV = (SV *) newSVpv(newpubout,ephpub_len);

err:

	EC_POINT_free(offsetpub);
	EC_POINT_free(newpub);
	BN_CTX_free(ctx);
	bp_key_free(bp_pubkey);
	//EC_GROUP_free(group);
	return returnSV;
}



/*
 *   Return success=0 hash (typically indicates failure to deserialize)
 */

// get counter party's publickey, create ephemeral key, and 
SV* picocoin_ecdh_encrypt(SV* publickey){
	STRLEN len; //calculated via SvPV
	uint8_t * pubkey = (uint8_t*) SvPV(publickey,len);
	size_t pk_len = (size_t) len;

	if(pk_len != 33){
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
	//uint8_t *buf = malloc((SHA256_DIGEST_LENGTH + ephpub_len) * sizeof(uint8_t));
	///memcpy(&buf[SHA256_DIGEST_LENGTH],ephbuf,ephpub_len);
	
	size_t sec_len = 0;
	uint8_t * ssbuf = sharedsecret(
		group, EC_KEY_get0_public_key(bp_pubkey->k), EC_KEY_get0_private_key(ephemeral_key), &sec_len
	);
	
	bp_key_free(bp_pubkey);
	EC_KEY_free(ephemeral_key);
	
	if(ssbuf != NULL){
		uint8_t * buf = OPENSSL_malloc(sec_len + ephpub_len);
		memcpy(&buf[0],ssbuf,sec_len);
		memcpy(&buf[sec_len],ephbuf,ephpub_len);
		OPENSSL_free(ssbuf);
		return (SV* ) newSVpv(buf,sec_len + ephpub_len);
	}
	else{
		
		return &PL_sv_undef;
	}
}


/*
 * have ephemeral public key and recepient private key 
 */
SV* picocoin_ecdh_decrypt(SV* publickey,SV* privatekey){
	STRLEN len; //calculated via SvPV
	uint8_t * pubkey = (uint8_t*) SvPV(publickey,len);
	size_t pubkey_len = (size_t) len;
	if(pubkey_len != 33){
		//fprintf(stderr,"part 1.1\n");
		return &PL_sv_undef;
	}
	uint8_t * privkey = (uint8_t*) SvPV(privatekey,len);
	size_t privk_len = (size_t) len;
	if(privk_len != 33 && privk_len != 32){
		return &PL_sv_undef;
	}
	

	// load in the ephemeral public key
	struct bp_key *bp_pubkey = malloc(sizeof(struct bp_key));
	if(!bp_key_init(bp_pubkey)){
		//fprintf(stderr,"part 3.1\n");
		bp_key_free(bp_pubkey);
		return &PL_sv_undef;
	}
	if(!bp_pubkey_set(bp_pubkey, pubkey, pubkey_len)){
		//fprintf(stderr,"part 4.1\n");
		bp_key_free(bp_pubkey);
		return &PL_sv_undef;
	}
	
	// load in the recepient private key
	struct bp_key *bp_privkey = malloc(sizeof(struct bp_key));
	if(!bp_key_init(bp_privkey)){
		bp_key_free(bp_pubkey);
		bp_key_free(bp_privkey);
		return &PL_sv_undef;
	}
	if(!bp_key_secret_set(bp_privkey, privkey, 32)){
		bp_key_free(bp_pubkey);
		bp_key_free(bp_privkey);
		return &PL_sv_undef;
	}

	
	// calculate the shared secret with the ephemeral private key and recepient public key
	//int field_size = EC_GROUP_get_degree(EC_KEY_get0_group(key));

	const EC_GROUP *group = EC_KEY_get0_group(bp_privkey->k);

	size_t sec_len = 0;
	uint8_t * ssbuf = sharedsecret(
		group,  EC_KEY_get0_public_key(bp_pubkey->k), EC_KEY_get0_private_key(bp_privkey->k), &sec_len
	);
	bp_key_free(bp_pubkey);
	bp_key_free(bp_privkey);
	
	if(ssbuf != NULL){
		return (SV* ) newSVpv(ssbuf,sec_len);
	}
	else{
		return &PL_sv_undef;
	}
	
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
	//fprintf(stderr,"hello - 0\n");
	// get the public key
	void *pubkey = NULL;
	size_t pk_len = 0;
	//fprintf(stderr,"hello - 1\n");
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
	//fprintf(stderr,"hello - 2\n");
	uint8_t *privkey = malloc(33 * sizeof(uint8_t));
	if(bp_key_secret_get(privkey, 32, &hdkey.key)){
		privkey[32] = 0x01;
		hv_store(rh, "private key", 11, newSVpv(privkey,33), 0);
		//fprintf(stderr,"pk length=%d\n",prk_len);
	}
	else{
		free(privkey);
	}
	//fprintf(stderr,"hello - 4\n");
	
	
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

HV* picocoin_generatehdkeymaster(SV* seed,int vers){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//fprintf(stderr,"Hi - 1\n");
	uint32_t version = (uint32_t) vers;
	
	//fprintf(stderr,"Hi - 2: v=%d p=%d\n",version,0x0488ADE4);
	if( !(version == 0x0488B21E || version == 0x0488ADE4 || version == 0x043587CF || version == 0x04358394) ){
		return picocoin_returnblankhdkey(rh);
	}
	
	STRLEN len; //calculated via SvPV
	uint8_t * seed_raw = (uint8_t*) SvPV(seed,len);
	//fprintf(stderr,"Hi - 3\n");
	struct hd_extended_key hdkey;
	if(!hd_extended_key_init(&hdkey)){
		return picocoin_returnblankhdkey(rh);
	}
	//fprintf(stderr,"Hi - 4\n");
	if(!hd_extended_key_generate_master(&hdkey, seed_raw, len)){
		return picocoin_returnblankhdkey(rh);
	}
	
	// check the version!!!!
	// (mainnet: 0x0488B21E public, 0x0488ADE4 private; testnet: 0x043587CF public, 0x04358394 private)
	hdkey.version = version;
	//fprintf(stderr,"v=%d vs p=%d",version,0x0488ADE4);
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
picocoin_generatehdkeymaster(seed,vers)
	SV* seed
	int vers

HV*
picocoin_generatehdkeychild(xpriv,child_index)
	SV* xpriv
	int child_index
	
SV*
picocoin_ecdh_encrypt(publickey)
	SV* publickey

SV*
picocoin_ecdh_decrypt(publickey, privatekey)
	SV* publickey
	SV* privatekey
	
SV*
picocoin_offset_private_key(privatekey,offset)
	SV* privatekey
	SV* offset
	
SV*
picocoin_offset_public_key(publickey,offset)
	SV* publickey
	SV* offset
