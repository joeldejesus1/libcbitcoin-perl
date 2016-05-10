#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <ccoin/hdkeys.h>

#include <assert.h>
#include <ccoin/base58.h>
#include <openssl/err.h>
#include <ccoin/cstr.h>


// just a dummy function
int dummy(int arg){
	return 1;
}

char* picocoin_base58_encode(SV* x){

	STRLEN len; //calculated via SvPV
	uint8_t * xmsg = (uint8_t*) SvPV(x,len);
	cstring * ans = base58_encode(xmsg,(size_t) len);
	return ans->str;
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
	
PROTOTYPES: DISABLED


int
dummy (arg)
	int	arg
	
char* 
picocoin_base58_encode(x)
	SV* x
