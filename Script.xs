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
#include <CBBigInt.h>

//bool CBInitScriptFromString(CBScript * self, char * string)
char* scriptToString(CBScript* script){
	char* answer = (char *)malloc(CBScriptStringMaxSize(script)*sizeof(char));
	CBScriptToString(script, answer);
	return answer;

}

CBScript* stringToScript(char* scriptstring){
	CBScript* self;
	if(CBInitScriptFromString(self,scriptstring)){
		return self;
	}
	else{
		return NULL;
	}
}

char* CBScript_obj_to_serializeddata(CBScript* script){
	char* answer = (char *)malloc(CBScriptStringMaxSize(script)*sizeof(char));
	CBScriptToString(script, answer);
	return answer;

}
CBScript* CBScript_serializeddata_to_obj(char* scriptstring){
	CBScript* self;
	if(CBInitScriptFromString(self,scriptstring)){
		return self;
	}
	else{
		return NULL;
	}
}

//////////////////////// perl export functions /////////////


// 20 byte hex string (Hash160) to address
char* newAddressFromRIPEMD160Hash(char* hexstring, int prefix){
	CBByteArray* array = hexstring_to_bytearray(hexstring);
	fprintf(stderr,"Array Length=%d\n",array->length);
	CBAddress * address = CBNewAddressFromRIPEMD160Hash(CBByteArrayGetData(array), prefix, true);
	CBByteArray * addressstring = CBChecksumBytesGetString(CBGetChecksumBytes(address));
	CBReleaseObject(address);
	return (char *)CBByteArrayGetData(addressstring);
}




/* Return 1 if this script is multisig, 0 for else*/
// this function does not work
char* whatTypeOfScript(char* scriptstring){
	CBScript * script = CBNewScriptFromString(scriptstring);
	if(script == NULL){
		return "NULL";
	}
	if(CBScriptIsMultisig(script)){
		return "multisig";
	}
	else if(CBScriptIsP2SH(script)){
		return "p2sh";
	}
	else if(CBScriptIsPubkey(script)){
		return "pubkey";
	}
	else if(CBScriptIsKeyHash(script)){
		return "p2pkh";
	}
	else{
		return "FAILED";
	}

}

char* script_to_p2sh(char* scriptstring){
	CBScript * script = CBNewScriptP2SHOutput(CBNewScriptFromString(scriptstring));
    char* answer = (char *)malloc(CBScriptStringMaxSize(script)*sizeof(char));
    CBScriptToString(script, answer);
    CBFreeScript(script);
    return answer;
}

/*char* serializeP2SH(char* scriptstring){
	CBScript * script = CBNewScriptP2SHOutput(CBNewScriptFromString(scriptstring));
	return CBScript_obj_to_serializeddata(script);
}*/



char* addressToHex(char* addressString){
    CBByteArray * addrStr = CBNewByteArrayFromString(addressString, true);

    CBAddress * addr = CBNewAddressFromString(addrStr, false);
    if(addr == NULL)
    	return "";
    
    uint8_t * pubKeyHash = CBByteArrayGetData(CBGetByteArray(addr)) + 1;
    
    int prefix = (int) CBChecksumBytesGetPrefix(addr);
    
    
    CBScript *script;
    char *answer;
    
    if(prefix == 0x00){
    	return bytearray_to_hexstring(CBGetByteArray(addr),CBGetByteArray(addr)->length);
    	//return "p2pkh";
    }
    else if(prefix == 0x05){
    	// see CBInitChecksumBytesFromString for details
    	return bytearray_to_hexstring(CBGetByteArray(addr),CBGetByteArray(addr)->length);
	
    	uint8_t hash[32];
		uint32_t keylength = 20;
		//CBSha256(pubKeyHash, keylength, hash);

		
		script = (CBScript *) CBNewByteArrayOfSize(
			1 + 1 + keylength + 1
		);
		CBByteArraySetByte(script, 0, CB_SCRIPT_OP_HASH160);
		// indicates 20 bytes follow, see https://github.com/bitcoin/bips/blob/master/bip-0016.mediawiki
		CBByteArraySetByte(script, 1, 0x14);
		CBByteArraySetBytes(script, 2, pubKeyHash, keylength);
		CBByteArraySetByte(script,
			2 + keylength , 
			CB_SCRIPT_OP_EQUAL
		);
    	
    }
    else{
    	return "unknown";
    }
    //return bytearray_to_hexstring(CBGetByteArray(addr), 20);
    //CBFreeAddress(addr);
    return CBScript_obj_to_serializeddata(script);
	//return "crap";
}

// CBScript * CBNewScriptPubKeyOutput(uint8_t * pubKey);
char* pubkeyToScript (char* pubKeystring){
	// convert to uint8_t *
	CBByteArray * masterString = CBNewByteArrayFromString(pubKeystring, true);
	CBScript * script = CBNewScriptPubKeyOutput(CBByteArrayGetData(masterString));
	CBReleaseObject(masterString);

	return scriptToString(script);
}

//http://stackoverflow.com/questions/1503763/how-can-i-pass-an-array-to-a-c-function-in-perl-xs#1505355
//CBNewScriptMultisigOutput(uint8_t ** pubKeys, uint8_t m, uint8_t n);
//char* multisigToScript (char** multisigConcatenated,)
char* multisigToScript(SV* pubKeyArray,int mKeysInt, int nKeysInt) {
	uint8_t mKeys, nKeys;
	mKeys = (uint8_t)mKeysInt;
	nKeys = (uint8_t)nKeysInt;

	int n;
	I32 length = 0;
    if ((! SvROK(pubKeyArray))
    || (SvTYPE(SvRV(pubKeyArray)) != SVt_PVAV)
    || ((length = av_len((AV *)SvRV(pubKeyArray))) < 0))
    {
        return 0;
    }
    /* Create the array which holds the return values. */
	uint8_t** multisig = (uint8_t**)malloc(nKeysInt * sizeof(uint8_t*));

	for (n=0; n<=length; n++) {
		STRLEN l;

		char * fn = SvPV (*av_fetch ((AV *) SvRV (pubKeyArray), n, 0), l);

		CBByteArray * masterString = hexstring_to_bytearray(fn);

		// this line should just assign a uint8_t * pointer
		multisig[n] = CBByteArrayGetData(masterString);

		//CBReleaseObject(masterString);

	}
	CBScript* finalscript =  CBNewScriptMultisigOutput(multisig,mKeys,nKeys);

	return scriptToString(finalscript);
}



MODULE = CBitcoin::Script	PACKAGE = CBitcoin::Script	

PROTOTYPES: DISABLE


char*
script_to_p2sh(scriptstring)
	char* scriptstring

char *
newAddressFromRIPEMD160Hash (hexstring,prefix)
	char *	hexstring
	int		prefix

char *
whatTypeOfScript (scriptstring)
	char *	scriptstring

char *
addressToHex (addressString)
	char *	addressString

char *
pubkeyToScript (pubKeystring)
	char *	pubKeystring

char *
multisigToScript (pubKeyArray, mKeysInt, nKeysInt)
	SV *	pubKeyArray
	int	mKeysInt
	int	nKeysInt

