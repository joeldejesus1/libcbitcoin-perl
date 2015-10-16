#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <openssl/ssl.h>
#include <openssl/ripemd.h>
#include <openssl/rand.h>
#include <CBHDKeys.h>
#include <CBChecksumBytes.h>
#include <CBAddress.h>
#include <CBWIF.h>
#include <CBByteArray.h>
#include <CBBase58.h>
#include <CBScript.h>
#include <CBMessage.h>
#include <CBBlock.h>
#include <CBNetworkFunctions.h>
#include <CBNetworkCommunicator.h>
#include "spv.h"




/*
 * Initialize peer
 * 
 */


HV* block_block_to_hash(CBBlock* x){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	uint8_t * hash = malloc(32*sizeof(uint8_t));
	CBBlockCalculateHash(x,hash);	
	hv_store(rh, "hash", 4, newSVpv(hash,32), 0);
	
	
	hv_store(rh, "nonce", 5, newSViv(x->nonce), 0);
	hv_store(rh, "target", 6, newSViv(x->target), 0);
	hv_store(rh, "transactionNum", 14, newSViv(x->transactionNum), 0);
	hv_store(rh, "version", 7, newSViv(x->version), 0);
	hv_store(rh, "timestamp", 9, newSViv(x->time), 0);

	hv_store(rh, "prevBlockHash", 13, newSVpv(CBByteArrayGetData(x->prevBlockHash),x->prevBlockHash->length), 0);
	hv_store(rh, "merkleRoot", 10, newSVpv(CBByteArrayGetData(x->merkleRoot),x->merkleRoot->length), 0);
	return rh;
}


HV* block_GenesisBlock(void){
	
	CBBlock * x = CBNewBlockGenesis();
	HV * rh = block_block_to_hash(x);
	if(CBGetMessage(x)->serialised){
		hv_store(rh, "data", 4, newSVpv(CBByteArrayGetData(CBGetMessage(x)->bytes),CBGetMessage(x)->bytes->length), 0);
	}
	else{
		hv_store(rh, "data", 4, newSViv(0), 0);
	}
	CBDestroyBlock(x);
	
	return rh;
}

HV* block_BlockFromData(SV* data,int AreThereTx){
	bool tx;
	if(AreThereTx == 0){
		tx = false;
	}
	else{
		tx = true;
	}
	
	
	
	STRLEN len;
	uint8_t* data1 = (uint8_t*) SvPV(data,len);
	CBByteArray * data2 = CBNewByteArrayWithDataCopy(data1, (uint32_t) len);
	CBBlock * block = CBNewBlockFromData(data2);
	uint32_t length = CBBlockDeserialise(block,tx);
	if(length == 0){
		HV * nullrh = (HV *) sv_2mortal ((SV *) newHV ());
		hv_store(nullrh, "result", 6, newSViv(0), 0);
		return nullrh;
	}
	HV * rh = block_block_to_hash(block);
	
	if(CBGetMessage(block)->serialised){
		hv_store(rh, "data", 4, newSVpv(CBByteArrayGetData(CBGetMessage(block)->bytes),CBGetMessage(block)->bytes->length), 0);
	}
	else{
		hv_store(rh, "data", 4, newSViv(0), 0);
	}
	
	CBDestroyBlock(block);
	hv_store(rh, "result", 6, newSViv(1), 0);
	return rh;
}



MODULE = CBitcoin::Block	PACKAGE = CBitcoin::Block	

PROTOTYPES: DISABLE



HV * 
block_GenesisBlock ()

HV * 
block_BlockFromData (data,AreThereTx)
	SV* data
	int AreThereTx
	