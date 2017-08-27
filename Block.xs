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
#include <ccoin/buint.h>
#include <ccoin/util.h>
#include <ccoin/buffer.h>
#include <ccoin/core.h>
#include <ccoin/mbr.h>
#include <ccoin/message.h>
#include <ccoin/bloom.h>
#include <ccoin/serialize.h>
#include <ccoin/script.h>
//#include <ccoin/compat.h>
/*
 * typedef struct bu256 {
	uint32_t dword[BU256_WORDS];
} bu256_t;
 */



////// bloom filter ///////////

struct bloom* bloomfilter_des(SV* bfdata){
	STRLEN len; //calculated via SvPV
	uint8_t * bfdata_pointer = (uint8_t*) SvPV(bfdata,len);

	if(len == 0){
		return NULL;
	}
	struct bloom * bf = malloc(sizeof(*bf));
	__bloom_init(bf);
	
	struct const_buffer bfbuff= {bfdata_pointer,len};
	
	if(!deser_bloom(bf, &bfbuff)){
		bloom_free(bf);
		return NULL;
	}	
	
	return bf;
}


/*
 * extern bool bloom_contains(struct bloom *bf, const void *data, size_t data_len);

extern bool bloom_size_ok(const struct bloom *bf);
 */
void bloomfilter_insert(struct bloom* bf, SV* arrayref){
	
	if(!SvROK(arrayref)){
		return;
	}
	SV* tmpSV = (SV*)SvRV(arrayref);
	
	if (SvTYPE(tmpSV) != SVt_PVAV) {
		return;
	}
	AV* array = (AV*)tmpSV;
	//fprintf(stderr, "insert - 1");
	int i;
	for (i=0; i<=av_len(array); i++) {
		SV** elem = av_fetch(array, i, 0);
		if (elem != NULL){
			STRLEN len;
			uint8_t * elem_pointer = (uint8_t*) SvPV(*elem,len);
			bloom_insert(bf,elem_pointer,(size_t) len);
		}
	}
}


struct bloom* bloomfilter_create(int nElements, double nFPRate){
	//fprintf(stderr,"create - 1\n");
	if(nElements <= 0 || nFPRate <= 0 || 1 < nFPRate){
		//fprintf(stderr,"create - 1\n");
		return NULL;
	}
	//fprintf(stderr,"create - 2\n");
	//struct bloom * bf = {
	//		cstr_new_sz(1024),0
	//};
	struct bloom * bf = malloc(sizeof(*bf));
	
	//fprintf(stderr,"create - 3(%d,%f)\n",nElements,nFPRate);
	if(!bloom_init(bf,(uint32_t) nElements,nFPRate)){
		//fprintf(stderr,"create - 4\n");
		bloom_free(bf);
		return NULL;
	}
	//fprintf(stderr,"create - 5\n");
	return bf;	
}

// struct const_buffer *buf
// x->str x->len
bool parse_bloomfilter_scriptSig(const struct bloom* bf, const cstring *script){
	if(script->len == 0 || script->len > 10000){
		return false;
	}
	//fprintf(stderr,"hi - 1 - len=%d\n",script->len);
	struct bscript_op op;
	
	int cursor = 0;
	
	uint8_t * buf_str = script->str;
	
	bool response = false;
	
	while(cursor < script->len){
		struct const_buffer buf = { &buf_str[cursor],1};
		uint8_t opcode;
		
		if (!deser_bytes(&opcode, &buf, 1))
			goto out;
		cursor += 1;
		
		op.op = opcode;
		
		uint32_t data_len;
		
		bool next = false;
		
		if (opcode < ccoin_OP_PUSHDATA1){
			data_len = opcode;
		}
		else if (opcode == ccoin_OP_PUSHDATA1) {
			uint8_t v8;
			if (!deser_bytes(&v8, &buf, 1))
				goto out;
			data_len = v8;
			cursor += 1;
		}
		else if (opcode == ccoin_OP_PUSHDATA2) {
			uint16_t v16;
			if (!deser_u16(&v16, &buf))
				goto out;
			data_len = v16;
			cursor += 2;
		}
		else if (opcode == ccoin_OP_PUSHDATA4) {
			uint32_t v32;
			if (!deser_u32(&v32, &buf))
				goto out;
			data_len = v32;
			cursor += 4;
		} else {
			// not push data
			op.data.p = NULL;
			op.data.len = 0;
			next = true;
		}
		op.data.p =  &buf_str[cursor];
		
		
		
		if (!next && 1 < op.data.len && bloom_contains(bf,op.data.p,op.data.len)){
			// set the cursor past the end of the script  in order to exit the while loop
			cursor += script->len * 2;
			// mark true because we have a public key that we know of being used to sign a transaction
			response = true;
		}

		cursor += op.data.len;
	}

out:
	
	return response;
}


////////// extra ///////////////

void copy256bithash(uint8_t *out, const bu256_t *in){
	
	int i;
	for(i=0;i<8;i++){
		memcpy((uint8_t *) out[4*i],in->dword[i],4);
	}
}

/*
 *   Return success=0 hash (typically indicates failure to deserialize)
 */
HV* picocoin_returnblankblock(HV * rh){
	hv_store(rh, "success", 7, newSViv((int) 0), 0);
	return rh;
}


// 
HV* picocoin_returnblock(HV * rh, const struct bp_block *block, struct bloom* bf){
	//fprintf(stderr,"hi - 4\n");
	hv_store(rh, "version", 7, newSViv( block->nVersion), 0);
	//fprintf(stderr,"nVersion=%d\n"double,block->nVersion);
	hv_store(rh, "time", 4, newSViv( block->nTime), 0);
	//fprintf(stderr,"nTime=%d\n",block->nTime);
	hv_store(rh, "bits", 4, newSViv( block->nBits), 0);
	//fprintf(stderr,"bits=%d\n",block->nBits);
	hv_store(rh, "nonce", 5, newSViv( block->nNonce), 0);
	//fprintf(stderr,"nonce=%d\n",block->nNonce);
	hv_store(rh, "success", 7, newSViv((int) 1), 0);
	
	// put bits into hex format (full 256bit integer to make it easier to handle in perl)
	mpz_t target;
	mpz_init(target);
	u256_from_compact(target, block->nBits);
	uint8_t * bitslong = mpz_get_str(NULL, 16, target);
	mpz_clear(target);
	hv_store(rh, "bitslong", 8, newSVpv(bitslong,strlen(bitslong) + 1), 0);
	
	
	
	char x1[BU256_STRSZ];
	bu256_hex(x1,&block->hashPrevBlock);
	hv_store(rh, "prevBlockHash", 13, newSVpv(x1,BU256_STRSZ), 0);
	//uint8_t *hash1 = malloc(32 * sizeof(uint8_t));
	//copy256bithash(hash1,&block->hashPrevBlock);
	//hv_store(rh, "prevBlockHash", 13, newSVpv(hash1,32), 0);
	
	
	char x2[BU256_STRSZ];
	bu256_hex(x2,&block->hashMerkleRoot);
	hv_store(rh, "merkleRoot", 10, newSVpv(x2, BU256_STRSZ ), 0);
	//uint8_t *hash2 = malloc(32 * sizeof(uint8_t));
	//copy256bithash(hash2,&block->hashMerkleRoot);
	//hv_store(rh, "merkleRoot", 10, newSVpv(hash2,32 ), 0);
	
	
	// sha256_valid
	if(block->sha256_valid){
		// sha256
		
		char x3[BU256_STRSZ];
		bu256_hex(x3, &block->sha256);
		hv_store(rh, "sha256", 6, newSVpv(x3,BU256_STRSZ), 0);
		//uint8_t *hash3 = malloc(32 * sizeof(uint8_t));
		//copy256bithash(hash3,&block->sha256);
		//hv_store(rh, "sha256", 6, newSVpv(hash3,32), 0);
	}
	
	
	
	//hd_extended_key_free(&hdkey);
	// parr *vtx; 
	//parr *vtx = block->vtx;
	//fprintf(stderr,"hi %s\n",block->vtx->len);
	if (!block->vtx || !block->vtx->len){
		return rh;
	}
	
    fprintf(stderr,"txs %d\n",block->vtx->len);
	
	int i;
	AV* avTX = (AV *) sv_2mortal ((SV *) newAV ());
	for(i=0;i<block->vtx->len;i++){
		
		
		
		struct bp_tx *tx;
		tx = parr_idx(block->vtx, i);
		
		HV * rhSingleTX= (HV *) sv_2mortal ((SV *) newHV ());
		
		bp_tx_calc_sha256(tx);
		
		if(tx->sha256_valid){
			char txhash[BU256_STRSZ];
			bu256_hex(txhash, &tx->sha256);
			hv_store( rhSingleTX, "hash", 4, newSVpv( txhash,  BU256_STRSZ), 0);
		}

		if(i == 0){
			fprintf(stderr,"coinbase tx\n");
		}
		
		
		bool add_tx_to_db = false;
		//tx->vin tx->vout
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
				if(bf != NULL && !add_tx_to_db){
					// check to see if this transaction should be included
					add_tx_to_db = bloom_contains(bf,prevHash,BU256_STRSZ-1);

				}
				
				
				
				if(txin->scriptSig && txin->scriptSig->len){
					// scriptSig
					uint8_t * scriptSig = malloc(txin->scriptSig->len * sizeof(uint8_t) );
					memcpy(scriptSig,txin->scriptSig->str,txin->scriptSig->len);
					//SV* ans_sv = newSVpv(answer,length);
					hv_store( rhtxin, "scriptSig", 9, newSVpv( scriptSig,  txin->scriptSig->len), 0);
					
					
					if(parse_bloomfilter_scriptSig(bf, txin->scriptSig)){
						add_tx_to_db = true;
					}
					else{
						fprintf(stderr,"bloom filter broken?\n");
					}
				}
				
				
				av_push(avtxin, newRV((SV *) rhtxin));
				//av_push(avtxin, newSViv(j));
			}
			
			hv_store( rhSingleTX, "vin", 3, newRV((SV *)avtxin), 0);
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
				
				if(bf != NULL && !add_tx_to_db){
					// check to see if this transaction should be included
					add_tx_to_db = bloom_contains(bf,spk,txout->scriptPubKey->len);
				}
				
				
				av_push(avtxout, newRV((SV *) rhtxout));
				//av_push(avtxin, newSViv(j));
			}
			//av_push(avTX, newRV((SV *)avtxout) );
			//bloom_contains(struct bloom *bf, const void *data, size_t data_len);
			hv_store( rhSingleTX, "vout", 4, newRV((SV *)avtxout), 0);
		}
		
		if(bf == NULL || (bf != NULL && add_tx_to_db) ){
			// bp_block_merkle_branch(const struct bp_block *block,const parr *mrktree,unsigned int txidx)
			// bp_check_merkle_branch(bu256_t *hash, const bu256_t *txhash_in,const parr *mrkbranch, unsigned int txidx)
			// provide a merkle branch for each transaction
			av_push(avTX, newRV((SV *)rhSingleTX) );
		}
	}
	hv_store(rh, "tx", 2,  newRV((SV *)avTX)  , 0);
	
	
	return rh;
}

HV* picocoin_block_des(SV* blockdata,int headerOnly){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	STRLEN len_blkdata;
	uint8_t * blkdata_pointer = (uint8_t*) SvPV(blockdata,len_blkdata);
	struct const_buffer blkbuf = { blkdata_pointer, len_blkdata };
	
	struct bp_block block;
	
	bp_block_init(&block);
	//fprintf(stderr,"hi - 1\n");
	if(!deser_bp_block(&block, &blkbuf)){
		bp_block_free(&block);	
		return picocoin_returnblankblock(rh);
	}
	//fprintf(stderr,"hi - 2\n");
	if(headerOnly == 0 && !bp_block_valid(&block)){
		bp_block_free(&block);
		return picocoin_returnblankblock(rh);
	}
	else{
		bp_block_calc_sha256(&block);
	}
	//fprintf(stderr,"hi - 3\n");
	
	
	
	
	
	picocoin_returnblock(rh,&block,NULL);
	bp_block_free(&block);
	return rh;
}


HV* picocoin_block_des_with_bloomfilter(SV* blockdata,SV* bfdata){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	
	struct bloom* bf = bloomfilter_des(bfdata);
	if(bf == NULL){
		return picocoin_returnblankblock(rh);
	}
	
	STRLEN len_blkdata;
	uint8_t * blkdata_pointer = (uint8_t*) SvPV(blockdata,len_blkdata);
	struct const_buffer blkbuf = { blkdata_pointer, len_blkdata };
	
	struct bp_block block;
	
	bp_block_init(&block);
	//fprintf(stderr,"hi - 1\n");
	if(!deser_bp_block(&block, &blkbuf)){
		bp_block_free(&block);	
		return picocoin_returnblankblock(rh);
	}
	//fprintf(stderr,"hi - 2\n");
	if(!bp_block_valid(&block)){
		bp_block_free(&block);
		return picocoin_returnblankblock(rh);
	}
	//fprintf(stderr,"hi - 3\n");
	bp_block_calc_sha256(&block);
	
	picocoin_returnblock(rh,&block,bf);
	bp_block_free(&block);
	return rh;
}

/*
 * Send an array ($script1, $script2, ...), nElements, and nFPRate
 */
HV* picocoin_bloomfilter_new(SV* arrayref, int nElements, double nFPRate){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	//newSViv( txout->nValue )
	//hv_store( rhtxin, "prevHash", 8, newSVpv( prevHash,  BU256_STRSZ), 0);
	//fprintf(stderr,"new - 1\n");
	struct bloom* bf = bloomfilter_create(nElements,nFPRate);
	//fprintf(stderr,"new - 1.2\n");
	if(bf == NULL){
		//fprintf(stderr,"new - 2\n");
		return picocoin_returnblankblock(rh);
	}
	bloomfilter_insert(bf, arrayref);
	// 
	hv_store( rh, "nElements", 9, newSViv( nElements ), 0);
	hv_store( rh, "nFPRate", 7, newSViv( nFPRate ), 0);
	hv_store( rh, "success", 7, newSViv( 1 ), 0);
	
	// serialize
	cstring *ser = cstr_new_sz(0);
	ser_bloom(ser, bf);
	bloom_free(bf);
	
	
	size_t length = ser->len;
	uint8_t *final = malloc(ser->len * sizeof(uint8_t));
	memcpy(final,ser->str,ser->len);
	cstr_free(ser,true);
	
	// TODO: check for memory leak
	hv_store( rh, "data", 4, newSVpv( final,  length), 0);
	//fprintf(stderr,"der test 2=%d\n",length);
	
	
	return rh;
}


/*
 *  scriptPubKey is the script in the previous transaction output.
 *  scriptSig is the script that gets ripemd hash160's into a p2sh (need this to make signature)
 *  outpoint = 32 byte tx hash followed by 4 byte uint32_t tx index
 */
/*
HV* xyy(SV* outpoint, SV* scriptPubKey){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	struct buffer * incomingdata;
	STRLEN len; //calculated via SvPV
	incomingdata->p = (const uint8_t*) SvPV(outpoint,len);
	incomingdata->len = len;
	
	struct bp_outpt * prev_output;
	bp_outpt_init(prev_output);
	if(!deser_bp_outpt(prev_output,incomingdata)){
		return picocoin_returnblankhdkey();
	}
	
}*/


MODULE = CBitcoin::Block	PACKAGE = CBitcoin::Block


PROTOTYPES: DISABLED


HV*
picocoin_bloomfilter_new(arrayref,nElements,nFPRate)
	SV* arrayref
	int nElements
	double nFPRate
	
HV*
picocoin_block_des(blockdata,headerOnly)
	SV* blockdata
	int headerOnly
	
HV*
picocoin_block_des_with_bloomfilter(blockdata,bfdata)
	SV* blockdata
	SV* bfdata