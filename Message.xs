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
#include "spv.h"


/* 
 * Input functions...........................................................................................
 */

CBSocketAddress* CBitcoinMessage_ConvertStringToSocketAddress(SV* ip,int port){
	CBSocketAddress* addr = (CBSocketAddress* ) malloc (sizeof (CBSocketAddress));
		
	STRLEN len;
	uint8_t* ip2 = (uint8_t*) SvPV(ip,len);
	// isolate the payload
	addr->ip = CBNewByteArrayWithData(ip2, (uint32_t) len);
	addr->port = (uint16_t) port;
	return addr;
}






/*
 * Output Functions ...........................................................................................
 * 
 */

int CBitcoinMessage_SocketAddressGetPort(CBSocketAddress* x){
	return (int) x->port;
}

HV* CBitcoinMessage_SocketAddressToString(CBSocketAddress* x){
	
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	hv_store(rh, "port", 4, newSViv(x->port), 0);
	hv_store(rh, "address", 7, newSVpv(CBByteArrayGetData(x->ip),x->ip->length), 0);
	
	return rh;
}




HV* getversion1(SV* ip,int port){
	return CBitcoinMessage_SocketAddressToString(CBitcoinMessage_ConvertStringToSocketAddress(ip,port));
}






// newSVnv for floaters, newSViv for integers, and newSVpv(char* x,int y) for character arrayss

HV *  testmsg(char * x, int size){
	
	
	int f = spv_dummy();
	
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	hv_store(rh, "eatme", 5, newSVpv(x,size), 0);
	return rh;
}





// check CBNetworkCommunicatorOnMessageReceived in CBNetworkCommunicator.c on how to handle incoming messages

bool CheckPayloadCheckSum(CBByteArray * data, uint8_t *checksum){
	
	// Check checksum
	uint8_t hash[32];
	uint8_t hash2[32];
	
	CBSha256(CBByteArrayGetData(data), data->length, hash);
	CBSha256(hash, 32, hash2);
	
	if (memcmp(hash2, checksum, 4)) {
		// result is false
		return false;
	}
	else{
		return true;
	}
}

HV* CBitcoinMessageParseMessage(SV* msg){
	// set up the return hash
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	STRLEN len;
	uint8_t* msg1 = (uint8_t*) SvPV(msg,len);
	// isolate the payload
	CBByteArray * payload = CBNewByteArrayWithData(msg1+24, (uint32_t) len - 24);
	
	//checksum ([4,magic][12,command][4,length][4,checksum]
	uint8_t* checksum = msg1+20;
	if(!CheckPayloadCheckSum(payload,checksum)){
		hv_store(rh, "type", 4, newSViv(0), 0);
	}
	else{
		hv_store(rh, "type", 4, newSViv(1), 0);
	}
	
	
	/*
	
	CBMessage * msg;
	// does not copy data, keeps pointer reference
	CBInitMessageByData(msg,data);
	
	char output[CB_MESSAGE_TYPE_STR_SIZE];
	CBMessageTypeToString(msg.type,output);
	
	
	// $obj->{'type'} = 'msg type';
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	hv_store(rh, "type", 4, newSVpv(output,(int) CB_MESSAGE_TYPE_STR_SIZE), 0);
	*/
	return rh;
}


MODULE = CBitcoin::Message	PACKAGE = CBitcoin::Message	

PROTOTYPES: DISABLE

HV * 
testmsg (x,size)
	char*	x
	int		size
	
HV *
CBitcoinMessageParseMessage(msg)
	SV*		msg

HV *
getversion1(ip,port)
	SV*	ip
	int	port
	