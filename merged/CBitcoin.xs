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

// print CBByteArray to hex string
char* bytearray_to_hexstring(CBByteArray * serializeddata,uint32_t dlen){
	char* answer = malloc(dlen*sizeof(char*));
	CBByteArrayToString(serializeddata, 0, dlen, answer, 0);
	return answer;
}
CBByteArray* hexstring_to_bytearray(char* hexstring){
	CBByteArray* answer = CBNewByteArrayFromHex(hexstring);
	return answer;
}


// just a dummy function
int dummy(int arg){
	return 1;
}


MODULE = CBitcoin	PACKAGE = CBitcoin	


BOOT:
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK;
	boot_CBitcoin__Script(aTHX_ cv);
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK;
	boot_CBitcoin__CBHD(aTHX_ cv);
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK;
	boot_CBitcoin__TransactionInput(aTHX_ cv);
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK;
	boot_CBitcoin__TransactionOutput(aTHX_ cv);
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK;
	boot_CBitcoin__Transaction(aTHX_ cv);
	SPAGAIN; POPs;
	
PROTOTYPES: DISABLED


int
dummy (arg)
	int	arg
