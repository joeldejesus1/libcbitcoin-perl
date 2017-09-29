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


#ifndef standard_h_   /* Include guard */
#define standard_h_

/**
 * transaction related functions that comply with network rules prior to segwit2x and uahf forks
 */


struct hd_extended_key_serialized {
	uint8_t data[78];
};

int picocoin_tx_validate ( SV* txdata);
int picocoin_tx_validate_input (
		int index, SV* scriptPubKey_data, SV* txdata,int sigvalidate, int nHashType
);
SV* picocoin_tx_sign_p2pkh(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType, int amount);
SV* picocoin_tx_sign_p2p(SV* hdkey_data, SV* fromPubKey_data, SV* txdata,int nIndex, int nHashType, int amount);
HV* picocoin_emptytx(HV * rh);
HV* picocoin_returntx(HV * rh, const struct bp_tx *tx);
HV* picocoin_tx_des(SV* tx_data);


#endif // standard_h_
