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
#include <CBTransactionOutput.h>




CBTransactionOutput* stringToTransactionOutput(char* scriptstring, int valueInt){

	CBScript* script = CBNewScriptFromString(scriptstring);

	CBTransactionOutput* answer = CBNewTransactionOutput((uint64_t) valueInt,script);
	//CBFreeScript(script);
	//CBDestroyByteArray(prevOutHash);
	return answer;
}

CBTransactionOutput* CBTransactionOutput_serializeddata_to_obj(char* datastring){

	CBByteArray* data = hexstring_to_bytearray(datastring);

	CBTransactionOutput* txoutput = CBNewTransactionOutputFromData(data);
	int dlen = (int)CBTransactionOutputDeserialise(txoutput);

	//CBTransactionInputDeserialise(txinput);
	//CBDestroyByteArray(data);
	return txoutput;
}

char* CBTransactionOutput_obj_to_serializeddata(CBTransactionOutput * txoutput){
	CBTransactionOutputPrepareBytes(txoutput);
	int dlen = CBTransactionOutputSerialise(txoutput);
	CBByteArray* serializeddata = CBGetMessage(txoutput)->bytes;

	char* answer = bytearray_to_hexstring(serializeddata,dlen);

	return answer;
}



//////////////////////// perl export functions /////////////
//CBTransactionInput * CBNewTransactionInput(CBScript * script, uint32_t sequence, CBByteArray * prevOutHash, uint32_t prevOutIndex)
char* CBTransactionOutput_create_txoutput_obj(char* scriptstring, int valueInt){
	CBTransactionOutput* txoutput = stringToTransactionOutput(scriptstring,valueInt);
	char* answer = CBTransactionOutput_obj_to_serializeddata(txoutput);
	//CBFreeTransactionOutput(txoutput);
	return answer;
}

char* CBTransactionOutput_get_script_from_obj(char* serializedDataString){
	CBTransactionOutput* txoutput = CBTransactionOutput_serializeddata_to_obj(serializedDataString);
	char* scriptstring = scriptToString(txoutput->scriptObject);
	//CBFreeTransactionOutput(txoutput);
	return scriptstring;
}

int CBTransactionOutput_get_value_from_obj(char* serializedDataString){
	CBTransactionOutput* txoutput = CBTransactionOutput_serializeddata_to_obj(serializedDataString);
	uint64_t value = txoutput->value;
	CBFreeTransactionOutput(txoutput);
	return (int)value;
}





MODULE = CBitcoin::TransactionOutput	PACKAGE = CBitcoin::TransactionOutput	PREFIX = CBTransactionOutput_	

PROTOTYPES: DISABLE


char *
CBTransactionOutput_create_txoutput_obj (scriptstring, valueInt)
	char *	scriptstring
	int	valueInt

char *
CBTransactionOutput_get_script_from_obj (serializedDataString)
	char *	serializedDataString

int
CBTransactionOutput_get_value_from_obj (serializedDataString)
	char *	serializedDataString

