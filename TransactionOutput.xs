#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <ctype.h>
#include <errno.h>

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <assert.h>
#include <ccoin/util.h>
#include <ccoin/buffer.h>
#include <ccoin/script.h>
#include <ccoin/core.h>
#include <ccoin/mbr.h>
#include <ccoin/message.h>
//#include <ccoin/compat.h>

////// extra


int dummy4(int x) {
	return x;
}

/*
 *  scriptPubKey is the script in the previous transaction output.
 *  scriptSig is the script that gets ripemd hash160's into a p2sh (need this to make signature)
 *  outpoint = 32 byte tx hash followed by 4 byte uint32_t tx index
 */




MODULE = CBitcoin::TransactionOutput	PACKAGE = CBitcoin::TransactionOutput


PROTOTYPES: DISABLED

int
dummy4(x)
	int x
