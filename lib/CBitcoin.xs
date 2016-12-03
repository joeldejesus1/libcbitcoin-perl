#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <ccoin/hdkeys.h>

#include <assert.h>
#include <openssl/ripemd.h>
#include <ccoin/util.h>
#include <ccoin/base58.h>
#include <openssl/err.h>
#include <ccoin/cstr.h>


//#include "CBitcoin.h"


// just a dummy function
int dummy(int arg){
	return 1;
}

SV* picocoin_ripemd_hash160(SV* x){
	STRLEN len; //calculated via SvPV
	uint8_t * xmsg = (uint8_t*) SvPV(x,len);
	uint8_t md160[RIPEMD160_DIGEST_LENGTH];
	bu_Hash160(md160,xmsg,len);
	return newSVpv(md160,RIPEMD160_DIGEST_LENGTH);
}

SV* picocoin_base58_encode(SV* x){

	STRLEN len; //calculated via SvPV
	uint8_t * xmsg = (uint8_t*) SvPV(x,len);
	cstring * ans = base58_encode(xmsg,(size_t) len);
	int length = (ans->len)*sizeof(char);
	char * answer = malloc(length);
	//sprintf("%s",ans->str);
	memcpy(answer,ans->str,length);
	SV* ans_sv = newSVpv(answer,length);
	cstr_free(ans, true);
	return ans_sv;
	//return answer;
	/*int i;
	char * fullans = malloc((1 + ans->len) * sizeof(char));
	for(i=0;i<ans->len+1;i++){
		fullans[i] = ans->str[i];
	}
	cstr_free(ans, true);
	return fullans;
	*/
}

SV* picocoin_base58_decode(char* x){

	STRLEN len; //calculated via SvPV
	//uint8_t * xmsg = (uint8_t*) SvPV(x,len);
	cstring * ans = base58_decode(x);
	
	return newSVpv(ans->str,ans->len);
	/*int i;
	char * fullans = malloc((1 + ans->len) * sizeof(char));
	for(i=0;i<ans->len+1;i++){
		fullans[i] = ans->str[i];
	}
	cstr_free(ans, true);
	return fullans;
	*/
}




#define crutch_stack_wrap(directive) do { \
	PUSHMARK(SP);  \
	PUTBACK; \
	directive; \
	SPAGAIN; \
	PUTBACK; \
} while(0)


MODULE = CBitcoin	PACKAGE = CBitcoin	


BOOT:
	crutch_stack_wrap(boot_CBitcoin__CBHD(aTHX_ cv));
	crutch_stack_wrap(boot_CBitcoin__Script(aTHX_ cv));
	crutch_stack_wrap(boot_CBitcoin__TransactionInput(aTHX_ cv));
	crutch_stack_wrap(boot_CBitcoin__TransactionOutput(aTHX_ cv));
	crutch_stack_wrap(boot_CBitcoin__Transaction(aTHX_ cv));
	crutch_stack_wrap(boot_CBitcoin__Block(aTHX_ cv));
	
PROTOTYPES: DISABLED


int
dummy (arg)
	int	arg
	
SV* 
picocoin_base58_encode(x)
	SV* x

SV* 
picocoin_base58_decode(x)
	char* x

SV*
picocoin_ripemd_hash160(x)
	SV* x