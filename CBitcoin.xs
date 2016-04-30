#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>



// just a dummy function
int dummy(int arg){
	return 1;
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
