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
#include <ccoin/script.h>
#include <ccoin/core.h>
#include <ccoin/mbr.h>
#include <ccoin/message.h>
//#include <ccoin/compat.h>
/*
 * typedef struct bu256 {
	uint32_t dword[BU256_WORDS];
} bu256_t;
 */


/*
 *   Return success=0 hash (typically indicates failure to deserialize)
 */
HV* picocoin_returnblankblock(HV * rh){
	hv_store(rh, "success", 7, newSViv((int) 0), 0);
	return rh;
}

// given a full hdkey, fill in a perl hash with relevant data
HV* picocoin_returnblock(HV * rh, const struct bp_block *block){
	//fprintf(stderr,"hi - 4\n");
	hv_store(rh, "version", 7, newSViv( block->nVersion), 0);
	//fprintf(stderr,"nVersion=%d\n",block->nVersion);
	hv_store(rh, "time", 4, newSViv( block->nTime), 0);
	//fprintf(stderr,"nTime=%d\n",block->nTime);
	hv_store(rh, "bits", 4, newSViv( block->nBits), 0);
	//fprintf(stderr,"bits=%d\n",block->nBits);
	hv_store(rh, "nonce", 5, newSViv( block->nNonce), 0);
	//fprintf(stderr,"nonce=%d\n",block->nNonce);
	hv_store(rh, "success", 7, newSViv((int) 1), 0);
	
	char x1[BU256_STRSZ];
	bu256_hex(x1,&block->hashPrevBlock);
	hv_store(rh, "prevBlockHash", 13, newSVpv(x1,sizeof(x1)), 0);
	char x2[BU256_STRSZ];
	bu256_hex(x2,&block->hashMerkleRoot);
	hv_store(rh, "merkleRoot", 10, newSVpv(x2,sizeof(x2)), 0);
	
	
	// sha256_valid
	if(block->sha256_valid){
		// sha256
		char x3[BU256_STRSZ];
		bu256_hex(x3, &block->sha256);
		hv_store(rh, "sha256", 6, newSVpv(x3,sizeof(x3)), 0);
	}
	
	//hd_extended_key_free(&hdkey);
	// parr *vtx; 
	//parr *vtx = block->vtx;
	//fprintf(stderr,"hi %s\n",block->vtx->len);
	if (!block->vtx || !block->vtx->len){
		return rh;
	}
	
	//fprintf(stderr,"txs %d\n",block->vtx->len);
	
	int i;
	AV* avTX = (AV *) sv_2mortal ((SV *) newAV ());
	for(i=0;i<block->vtx->len;i++){
		struct bp_tx *tx;
		tx = parr_idx(block->vtx, i);
		
		HV * rhSingleTX= (HV *) sv_2mortal ((SV *) newHV ());
		
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
			
			hv_store( rhSingleTX, "vin", 4, newRV((SV *)avtxin), 0);
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
			
			hv_store( rhSingleTX, "vout", 4, newRV((SV *)avtxout), 0);
		}
		
		
		av_push(avTX, newRV((SV *)rhSingleTX) );
	}
	hv_store(rh, "tx", 2,  newRV((SV *)avTX)  , 0);
	
	
	return rh;
}

HV* picocoin_block_des(SV* blockdata){
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
	if(!bp_block_valid(&block)){
		bp_block_free(&block);
		return picocoin_returnblankblock(rh);
	}
	//fprintf(stderr,"hi - 3\n");
	
	picocoin_returnblock(rh,&block);
	bp_block_free(&block);
	return rh;
}

////// extra


int dummy6(int x) {
	return x;
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

int
dummy6(x)
	int x
	
HV*
picocoin_block_des(blockdata)
	SV* blockdata