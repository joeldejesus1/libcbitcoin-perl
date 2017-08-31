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
#include <ccoin/key.h>
#include <ccoin/script.h>
#include <ccoin/core.h>
#include <ccoin/hdkeys.h>
#include <ccoin/key.h>
#include <ccoin/serialize.h>

#include "standard.h"

/**
 * transaction related functions that comply with network rules of the uahf fork
 */

#ifndef uahf_h_   /* Include guard */
#define uahf_h_

/** Signature hash types/flags */
enum
{
	CB_SIGHASH_ALL = 1,
	CB_SIGHASH_NONE = 2,
	CB_SIGHASH_SINGLE = 3,
	CB_SIGHASH_FORKID = 0x40,
	CB_SIGHASH_ANYONECANPAY = 0x80,
};

int uahf_test(int x);

extern void uahf_bp_tx_sighash(bu256_t *hash, const cstring *scriptCode,
		   const struct bp_tx *txTo, unsigned int nIn,int nHashType);
SV* uahf_picocoin_tx_sign_p2pkh(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType);
SV* uahf_picocoin_tx_sign_p2p(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType);



#endif // uahf_h_
