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




HV *  testmsg(int x){
	HV * rh = (HV *) sv_2mortal ((SV *) newHV ());
	
	hv_store(rh, "eatme", 5, newSViv(x), 0);
	return rh;
}



MODULE = CBitcoin::Message	PACKAGE = CBitcoin::Message	

PROTOTYPES: DISABLE

HV * 
testmsg (x)
	int	x