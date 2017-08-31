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

int uahf_test(int x);

#endif // uahf_h_
