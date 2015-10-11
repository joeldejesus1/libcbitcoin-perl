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
#include <CBNetworkFunctions.h>
#include <CBNetworkCommunicator.h>
#include "spv.h"




/*
 * Initialize peer
 * 
 */

//int





/* 
 * Input functions...........................................................................................
 */

CBSocketAddress CBitcoinMessage_ConvertStringToSocketAddress(SV* ip,int port){
	CBSocketAddress addr;// = (CBSocketAddress* ) malloc (sizeof (CBSocketAddress));
		
	STRLEN len;
	uint8_t* ip2 = (uint8_t*) SvPV(ip,len);
	// isolate the payload
	addr.ip = CBNewByteArrayWithData(ip2, (uint32_t) len);
	addr.port = (uint16_t) port;
	

	
	return addr;
}




uint32_t testCBVersionSerialise(CBVersion * self, bool force){
	CBByteArray * bytes = CBGetMessage(self)->bytes;
	if (! bytes) {
		CBLogError("Attempting to serialise a CBVersion with no bytes.");
		return 0;
	}
	if (bytes->length < 46) {
		CBLogError("Attempting to serialise a CBVersion with less than 46 bytes.");
		return 0;
	}
	CBByteArraySetInt32(bytes, 0, self->version);
	CBByteArraySetInt64(bytes, 4, self->services);
	CBByteArraySetInt64(bytes, 12, self->time);

	if (! CBGetMessage(self->addRecv)->serialised // Serailise if not serialised yet.
		// Serialise if force is true.
		|| force
		// If the data shares the same data as this version message, re-serialise the receiving address, in case it got overwritten.
		|| CBGetMessage(self->addRecv)->bytes->sharedData == bytes->sharedData
		// Reserialise if the address has a timestamp
		|| (CBGetMessage(self->addRecv)->bytes->length != 26)) {

		if (CBGetMessage(self->addRecv)->serialised)
			// Release old byte array
			CBReleaseObject(CBGetMessage(self->addRecv)->bytes);
		CBGetMessage(self->addRecv)->bytes = CBByteArraySubReference(bytes, 20, bytes->length-20);

		if (! CBNetworkAddressSerialise(self->addRecv, false)) {
			CBLogError("CBVersion cannot be serialised because of an error with the receiving CBNetworkAddress");
			// Release bytes to avoid problems overwritting pointer without release, if serialisation is tried again.
			CBReleaseObject(CBGetMessage(self->addRecv)->bytes);
			return 0;
		}
	}else{
		// Move serialsed data to one location
		CBByteArrayCopyByteArray(bytes, 20, CBGetMessage(self->addRecv)->bytes);
		CBByteArrayChangeReference(CBGetMessage(self->addRecv)->bytes, bytes, 20);
	}
	//CBLogError("Here i am");
	//return 0;
	if (self->version >= 106) {
		if (bytes->length < 85) {
			CBLogError("Attempting to serialise a CBVersion with less than 85 bytes required.");
			return 0;
		}
		if (self->userAgent->length > 400) {
			CBLogError("Attempting to serialise a CBVersion with a userAgent over 400 bytes.");
			return 0;
		}
		if (! CBGetMessage(self->addSource)->serialised // Serailise if not serialised yet.
			// Serialise if force is true.
			|| force
			// If the data shares the same data as this version message, re-serialise the source address, in case it got overwritten.
			|| CBGetMessage(self->addSource)->bytes->sharedData == bytes->sharedData
			// Reserialise if the address has a timestamp
			|| (CBGetMessage(self->addSource)->bytes->length != 26)) {
			if (CBGetMessage(self->addSource)->serialised)
				// Release old byte array
				CBReleaseObject(CBGetMessage(self->addSource)->bytes);
			CBGetMessage(self->addSource)->bytes = CBByteArraySubReference(bytes, 46, bytes->length-46);
			if (! CBNetworkAddressSerialise(self->addSource, false)) {
				CBLogError("CBVersion cannot be serialised because of an error with the source CBNetworkAddress");
				// Release bytes to avoid problems overwritting pointer without release, if serialisation is tried again.
				CBReleaseObject(CBGetMessage(self->addSource)->bytes);
				return 0;
			}
		}else{
			// Move serialsed data to one location
			CBByteArrayCopyByteArray(bytes, 46, CBGetMessage(self->addSource)->bytes);
			CBByteArrayChangeReference(CBGetMessage(self->addSource)->bytes, bytes, 46);
		}
		//CBLogError("Here i am");
		//return 0;
		CBByteArraySetInt64(bytes, 72, self->nonce);
		CBVarInt varInt = CBVarIntFromUInt64(self->userAgent->length);
		CBByteArraySetVarInt(bytes, 80, varInt);
		if (bytes->length < 84 + varInt.size + varInt.val) {
			CBLogError("Attempting to deserialise a CBVersion without enough space to cover the userAgent and block height.");
			return 0;
		}
		//CBLogError("Here i am");
		//return 0;
		CBByteArrayCopyByteArray(bytes, 80 + varInt.size, self->userAgent);
		CBByteArrayChangeReference(self->userAgent, bytes, 80 + varInt.size);
		CBByteArraySetInt32(bytes, 80 + varInt.size + (uint32_t)varInt.val, self->blockHeight);

		// Ensure length is correct
		bytes->length = 84 + varInt.size + (uint32_t)varInt.val;
		CBGetMessage(self)->serialised = true;
		

		return bytes->length;
	}else{
		// Not the further message
		// Ensure length is correct
		bytes->length = 46;
	}

	CBGetMessage(self)->serialised = true;
	return bytes->length;
}



HV* createversion1(SV* addr_recv_ip,int addr_recv_port,SV* addr_from_ip, int addr_from_port, SV* lastseen, int version, int blockheight ){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	hv_store(rh, "port", 4, newSViv(addr_recv_port), 0);
	
	CBSocketAddress addr_recv = CBitcoinMessage_ConvertStringToSocketAddress(addr_recv_ip,addr_recv_port);
	CBSocketAddress addr_from = CBitcoinMessage_ConvertStringToSocketAddress(addr_from_ip,addr_from_port);
	
	// get lastseen as 64bit integer (http://stackoverflow.com/questions/9695720/how-do-i-convert-a-64bit-integer-to-a-char-array-and-back)
	STRLEN len;
	uint8_t* lastseenbytes = (uint8_t*) SvPV(lastseen,len);
	int64_t lastSeenInt;
	memcpy(&lastSeenInt, lastseenbytes, 8);
	
	
	uint64_t nonce = rand();
	
	CBNetworkAddress * addr_recv_netadddr = CBNewNetworkAddress(lastSeenInt, addr_recv, CB_SERVICE_NO_FULL_BLOCKS, true); //maybe should be argument...
	CBNetworkAddress * addr_from_netadddr = CBNewNetworkAddress(time(NULL), addr_from, CB_SERVICE_NO_FULL_BLOCKS, false);
	
//CBVersion * CBNewVersion(int32_t version, CBVersionServices services, int64_t time,
//		CBNetworkAddress * addRecv, CBNetworkAddress * addSource, uint64_t nounce, CBByteArray * userAgent, int32_t blockHeight)
	char string[] = "test v0.1";
	CBByteArray* useragent_ba = CBNewByteArrayFromString(string, true);
	
	CBVersion * ver = CBNewVersion((int32_t) version,CB_SERVICE_NO_FULL_BLOCKS, lastSeenInt, 
			addr_recv_netadddr, addr_from_netadddr, nonce, useragent_ba, (int32_t) blockheight);
	
	hv_store(rh, "length", 4, newSViv((int) CBVersionCalculateLength(ver)), 0);
	CBGetMessage(ver)->bytes = CBNewByteArrayOfSize(CBVersionCalculateLength(ver));

	char output[200];
	CBVersionToString(ver,output);
	
	//CBVersionPrepareBytes(ver);
	
	uint32_t length  = testCBVersionSerialise(ver, true);
	//strlen(output)
	fprintf(stderr,"Length=%d\n",CBGetMessage(ver)->bytes->length);
	hv_store(rh, "send_version", 12, newSVpv(CBGetMessage(ver)->bytes,CBGetMessage(ver)->bytes->length), 0);
	
	
	return rh;
	
	//return 1;
}

/*
 * Output Functions ...........................................................................................
 * 
 */

HV* CBitcoinMessage_SocketAddressToString(CBSocketAddress* x){
	
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	hv_store(rh, "port", 4, newSViv(x->port), 0);
	hv_store(rh, "address", 7, newSVpv(CBByteArrayGetData(x->ip),x->ip->length), 0);
	
	return rh;
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

	
HV*
createversion1(addr_recv_ip,addr_recv_port,addr_from_ip,addr_from_port,lastseen,version,blockheight)
	SV*	addr_recv_ip
	int	addr_recv_port
	SV*	addr_from_ip
	int	addr_from_port	
	SV* lastseen
	int version
	int blockheight