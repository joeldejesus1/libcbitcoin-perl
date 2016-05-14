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
#include <ccoin/buffer.h>
#include <ccoin/script.h>
#include <ccoin/core.h>
#include <ccoin/mbr.h>
#include <ccoin/message.h>
//#include <ccoin/compat.h>

////// extra


int dummy3(int x) {
	return x;
}

/*
 *  scriptPubKey is the script in the previous transaction output.
 *  scriptSig is the script that gets ripemd hash160's into a p2sh (need this to make signature)
 *  outpoint = 32 byte tx hash followed by 4 byte uint32_t tx index
 */

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
	
}


MODULE = CBitcoin::TransactionInput	PACKAGE = CBitcoin::TransactionInput


PROTOTYPES: DISABLED

int
dummy3(x)
	int x
