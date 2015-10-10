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




// newSVnv for floaters, newSViv for integers, and newSVpv(char* x,int y) for character arrayss

HV *  testmsg(char * x, int size){
	
	
	
	
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	hv_store(rh, "eatme", 5, newSVpv(x,size), 0);
	return rh;
}


int testmsg2(SV* x){
	STRLEN len;
	unsigned char* msg1 = (unsigned char*) SvPV(x,len);
	//CBByteArray * masterString = hexstring_to_bytearray(msg1);
	CBByteArray * masterString = CBNewByteArrayWithData(msg1, (uint32_t) len);
	
	return (int) len;
}


MODULE = CBitcoin::Message	PACKAGE = CBitcoin::Message	

PROTOTYPES: DISABLE

HV * 
testmsg (x,size)
	char*	x
	int		size
	
int 
testmsg2 (x)
	SV*	x