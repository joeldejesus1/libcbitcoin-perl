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
HV* picocoin_returnblock(HV * rh, const struct bp_block block){
	hv_store(rh, "version", 7, newSViv( block.nVersion), 0);
	hv_store(rh, "time", 4, newSViv( block.nTime), 0);
	hv_store(rh, "bits", 4, newSViv( block.nBits), 0);
	hv_store(rh, "nonce", 5, newSViv( block.nNonce), 0);
	char *x;
	bu256_hex(x,&block.hashPrevBlock);
	hv_store(rh, "prevBlockHash", 17, newSVpv(x,sizeof(x)), 0);
	bu256_hex(x,&block.hashMerkleRoot);
	hv_store(rh, "merkleRoot", 10, newSVpv(x,sizeof(x)), 0);
	
	
	// sha256_valid
	if(block.sha256_valid){
		// sha256
		bu256_hex(x, &block.sha256);
		hv_store(rh, "sha256", 6, newSVpv(x,sizeof(x)), 0);
	}
	
	//hd_extended_key_free(&hdkey);
	return rh;
}

HV* picocoin_block_des(SV* blockdata){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	fprintf(stderr,"hi - 1\n");
	STRLEN len_blkdata;
	uint8_t * blkdata_pointer = (uint8_t*) SvPV(blockdata,len_blkdata);
	struct const_buffer blkbuf = { blkdata_pointer, len_blkdata };
	fprintf(stderr,"hi - 2\n");
	struct bp_block *block;
	fprintf(stderr,"hi - 3\n");
	bp_block_init(block);
	fprintf(stderr,"hi - 3.1\n");
	if(!deser_bp_block(block, &blkbuf)){
		bp_block_free(block);
		fprintf(stderr,"hi - 5\n");
		return picocoin_returnblankblock(rh);
	}
	fprintf(stderr,"hi - 4\n");
	
	if(!bp_block_valid(block)){
		return picocoin_returnblankblock(rh);
	}
	
	
	return picocoin_returnblankblock(rh);
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