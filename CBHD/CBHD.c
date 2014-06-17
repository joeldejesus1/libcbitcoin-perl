/*
 * This file was generated automatically by ExtUtils::ParseXS version 2.2210 from the
 * contents of CBHD.xs. Do not edit this file, edit CBHD.xs instead.
 *
 *	ANY CHANGES MADE HERE WILL BE LOST! 
 *
 */

#line 1 "CBHD.xs"
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

CBHDKey* importDataToCBHDKey(char* privstring) {
	CBByteArray * masterString = CBNewByteArrayFromString(privstring, true);
	CBChecksumBytes * masterData = CBNewChecksumBytesFromString(masterString, false);
	CBReleaseObject(masterString);
	CBHDKey * masterkey = CBNewHDKeyFromData(CBByteArrayGetData(CBGetByteArray(masterData)));
	CBReleaseObject(masterData);
	return (CBHDKey *)masterkey;
}
//////////////////////// perl export functions /////////////

char* newMasterKey(int arg){
	CBHDKey * masterkey = CBNewHDKey(true);
	CBHDKeyGenerateMaster(masterkey,true);

	uint8_t * keyData = malloc(CB_HD_KEY_STR_SIZE);
	CBHDKeySerialise(masterkey, keyData);
	free(masterkey);
	CBChecksumBytes * checksumBytes = CBNewChecksumBytesFromBytes(keyData, 82, false);
	// need to figure out how to free keyData memory
	CBByteArray * str = CBChecksumBytesGetString(checksumBytes);
	CBReleaseObject(checksumBytes);
	return (char *)CBByteArrayGetData(str);
}

char* deriveChildPrivate(char* privstring,bool hard,int child){
	CBHDKey* masterkey = importDataToCBHDKey(privstring);

	// generate child key
	CBHDKey * childkey = CBNewHDKey(true);
	CBHDKeyChildID childID = { hard, child};
	CBHDKeyDeriveChild(masterkey, childID, childkey);
	free(masterkey);

	uint8_t * keyData = malloc(CB_HD_KEY_STR_SIZE);
	CBHDKeySerialise(childkey, keyData);
	free(childkey);

	CBChecksumBytes * checksumBytes = CBNewChecksumBytesFromBytes(keyData, 82, false);
	// need to figure out how to free keyData memory
	CBByteArray * str = CBChecksumBytesGetString(checksumBytes);
	CBReleaseObject(checksumBytes);
	return (char *)CBByteArrayGetData(str);
}

char* exportWIFFromCBHDKey(char* privstring){
	CBHDKey* cbkey = importDataToCBHDKey(privstring);
	CBWIF * wif = CBHDKeyGetWIF(cbkey);
	free(cbkey);
	CBByteArray * str = CBChecksumBytesGetString(wif);
	CBFreeWIF(wif);
	return (char *)CBByteArrayGetData(str);
}


char* exportAddressFromCBHDKey(char* privstring){
	CBHDKey* cbkey = importDataToCBHDKey(privstring);
	CBAddress * address = CBNewAddressFromRIPEMD160Hash(CBHDKeyGetHash(cbkey), CB_PREFIX_PRODUCTION_ADDRESS, false);
	free(cbkey);
	CBByteArray * addressstring = CBChecksumBytesGetString(CBGetChecksumBytes(address));
	CBReleaseObject(address);
	return (char *)CBByteArrayGetData(addressstring);
}

char* newWIF(int arg){
	CBKeyPair * key = CBNewKeyPair(true);
	CBKeyPairGenerate(key);
	CBWIF * wif = CBNewWIFFromPrivateKey(key->privkey, true, CB_NETWORK_PRODUCTION, false);
	free(key);
	CBByteArray * str = CBChecksumBytesGetString(wif);
	CBFreeWIF(wif);
	return (char *)CBByteArrayGetData(str);
}


char* publickeyFromWIF(char* wifstring){
	CBByteArray * old = CBNewByteArrayFromString(wifstring,true);
	CBWIF * wif = CBNewWIFFromString(old, false);
	CBDestroyByteArray(old);
	uint8_t  privKey[32];
	CBWIFGetPrivateKey(wif,privKey);
	CBFreeWIF(wif);
	CBKeyPair * key = CBNewKeyPair(true);
	CBInitKeyPair(key);
	memcpy(key->privkey, privKey, 32);
	CBKeyGetPublicKey(key->privkey, key->pubkey.key);
	return (char *)CBByteArrayGetData(CBNewByteArrayWithDataCopy(key->pubkey.key,CB_PUBKEY_SIZE));

}

char* addressFromPublicKey(char* pubkey){
	CBByteArray * pubkeystring = CBNewByteArrayFromString(pubkey, false);
	//CBChecksumBytes * walletKeyData = CBNewChecksumBytesFromString(walletKeyString, false);
	//CBHDKey * cbkey = CBNewHDKeyFromData(CBByteArrayGetData(CBGetByteArray(walletKeyData)));


	//CBByteArray * old = CBNewByteArrayFromString(pubkey,false);

	CBKeyPair * key = CBNewKeyPair(false);
	memcpy(key->pubkey.key, CBByteArrayGetData(CBGetByteArray(pubkeystring)), CB_PUBKEY_SIZE);
	CBDestroyByteArray(pubkeystring);
	// this code came from CBKeyPairGetHash definition
	uint8_t hash[32];
	CBSha256(key->pubkey.key, 33, hash);
	CBRipemd160(hash, 32, key->pubkey.hash);

	CBAddress * address = CBNewAddressFromRIPEMD160Hash(key->pubkey.hash, CB_PREFIX_PRODUCTION_ADDRESS, true);
	free(key);
	CBByteArray * addressstring = CBChecksumBytesGetString(CBGetChecksumBytes(address));
	CBReleaseObject(address);

	return (char *)CBByteArrayGetData(addressstring);
}

char* createWIF(int arg){
	CBKeyPair * key = CBNewKeyPair(true);
	CBKeyPairGenerate(key);
	CBWIF * wif = CBNewWIFFromPrivateKey(key->privkey, true, CB_NETWORK_PRODUCTION, false);
	CBByteArray * str = CBChecksumBytesGetString(wif);
	CBReleaseObject(wif);
	//return (char *)CBByteArrayGetData(str);
	CBReleaseObject(str);
	CBAddress * address = CBNewAddressFromRIPEMD160Hash(CBKeyPairGetHash(key), CB_PREFIX_PRODUCTION_ADDRESS, false);
	CBByteArray * string = CBChecksumBytesGetString(CBGetChecksumBytes(address));
	return (char *)CBByteArrayGetData(string);
	//CBReleaseObject(key);
	//CBReleaseObject(address);
}





#line 159 "CBHD.c"
#ifndef PERL_UNUSED_VAR
#  define PERL_UNUSED_VAR(var) if (0) var = var
#endif

#ifndef PERL_ARGS_ASSERT_CROAK_XS_USAGE
#define PERL_ARGS_ASSERT_CROAK_XS_USAGE assert(cv); assert(params)

/* prototype to pass -Wmissing-prototypes */
STATIC void
S_croak_xs_usage(pTHX_ const CV *const cv, const char *const params);

STATIC void
S_croak_xs_usage(pTHX_ const CV *const cv, const char *const params)
{
    const GV *const gv = CvGV(cv);

    PERL_ARGS_ASSERT_CROAK_XS_USAGE;

    if (gv) {
        const char *const gvname = GvNAME(gv);
        const HV *const stash = GvSTASH(gv);
        const char *const hvname = stash ? HvNAME(stash) : NULL;

        if (hvname)
            Perl_croak(aTHX_ "Usage: %s::%s(%s)", hvname, gvname, params);
        else
            Perl_croak(aTHX_ "Usage: %s(%s)", gvname, params);
    } else {
        /* Pants. I don't think that it should be possible to get here. */
        Perl_croak(aTHX_ "Usage: CODE(0x%"UVxf")(%s)", PTR2UV(cv), params);
    }
}
#undef  PERL_ARGS_ASSERT_CROAK_XS_USAGE

#ifdef PERL_IMPLICIT_CONTEXT
#define croak_xs_usage(a,b)	S_croak_xs_usage(aTHX_ a,b)
#else
#define croak_xs_usage		S_croak_xs_usage
#endif

#endif

/* NOTE: the prototype of newXSproto() is different in versions of perls,
 * so we define a portable version of newXSproto()
 */
#ifdef newXS_flags
#define newXSproto_portable(name, c_impl, file, proto) newXS_flags(name, c_impl, file, proto, 0)
#else
#define newXSproto_portable(name, c_impl, file, proto) (PL_Sv=(SV*)newXS(name, c_impl, file), sv_setpv(PL_Sv, proto), (CV*)PL_Sv)
#endif /* !defined(newXS_flags) */

#line 211 "CBHD.c"

XS(XS_CBitcoin__CBHD_newMasterKey); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_newMasterKey)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 1)
       croak_xs_usage(cv,  "arg");
    {
	int	arg = (int)SvIV(ST(0));
	char *	RETVAL;
	dXSTARG;

	RETVAL = newMasterKey(arg);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}


XS(XS_CBitcoin__CBHD_deriveChildPrivate); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_deriveChildPrivate)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 3)
       croak_xs_usage(cv,  "privstring, hard, child");
    {
	char *	privstring = (char *)SvPV_nolen(ST(0));
	bool	hard = (bool)SvTRUE(ST(1));
	int	child = (int)SvIV(ST(2));
	char *	RETVAL;
	dXSTARG;

	RETVAL = deriveChildPrivate(privstring, hard, child);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}


XS(XS_CBitcoin__CBHD_exportWIFFromCBHDKey); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_exportWIFFromCBHDKey)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 1)
       croak_xs_usage(cv,  "privstring");
    {
	char *	privstring = (char *)SvPV_nolen(ST(0));
	char *	RETVAL;
	dXSTARG;

	RETVAL = exportWIFFromCBHDKey(privstring);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}


XS(XS_CBitcoin__CBHD_exportAddressFromCBHDKey); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_exportAddressFromCBHDKey)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 1)
       croak_xs_usage(cv,  "privstring");
    {
	char *	privstring = (char *)SvPV_nolen(ST(0));
	char *	RETVAL;
	dXSTARG;

	RETVAL = exportAddressFromCBHDKey(privstring);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}


XS(XS_CBitcoin__CBHD_newWIF); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_newWIF)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 1)
       croak_xs_usage(cv,  "arg");
    {
	int	arg = (int)SvIV(ST(0));
	char *	RETVAL;
	dXSTARG;

	RETVAL = newWIF(arg);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}


XS(XS_CBitcoin__CBHD_publickeyFromWIF); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_publickeyFromWIF)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 1)
       croak_xs_usage(cv,  "wifstring");
    {
	char *	wifstring = (char *)SvPV_nolen(ST(0));
	char *	RETVAL;
	dXSTARG;

	RETVAL = publickeyFromWIF(wifstring);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}


XS(XS_CBitcoin__CBHD_addressFromPublicKey); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_addressFromPublicKey)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 1)
       croak_xs_usage(cv,  "pubkey");
    {
	char *	pubkey = (char *)SvPV_nolen(ST(0));
	char *	RETVAL;
	dXSTARG;

	RETVAL = addressFromPublicKey(pubkey);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}


XS(XS_CBitcoin__CBHD_createWIF); /* prototype to pass -Wmissing-prototypes */
XS(XS_CBitcoin__CBHD_createWIF)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
    if (items != 1)
       croak_xs_usage(cv,  "arg");
    {
	int	arg = (int)SvIV(ST(0));
	char *	RETVAL;
	dXSTARG;

	RETVAL = createWIF(arg);
	sv_setpv(TARG, RETVAL); XSprePUSH; PUSHTARG;
    }
    XSRETURN(1);
}

#ifdef __cplusplus
extern "C"
#endif
XS(boot_CBitcoin__CBHD); /* prototype to pass -Wmissing-prototypes */
XS(boot_CBitcoin__CBHD)
{
#ifdef dVAR
    dVAR; dXSARGS;
#else
    dXSARGS;
#endif
#if (PERL_REVISION == 5 && PERL_VERSION < 9)
    char* file = __FILE__;
#else
    const char* file = __FILE__;
#endif

    PERL_UNUSED_VAR(cv); /* -W */
    PERL_UNUSED_VAR(items); /* -W */
#ifdef XS_APIVERSION_BOOTCHECK
    XS_APIVERSION_BOOTCHECK;
#endif
    XS_VERSION_BOOTCHECK ;

        newXS("CBitcoin::CBHD::newMasterKey", XS_CBitcoin__CBHD_newMasterKey, file);
        newXS("CBitcoin::CBHD::deriveChildPrivate", XS_CBitcoin__CBHD_deriveChildPrivate, file);
        newXS("CBitcoin::CBHD::exportWIFFromCBHDKey", XS_CBitcoin__CBHD_exportWIFFromCBHDKey, file);
        newXS("CBitcoin::CBHD::exportAddressFromCBHDKey", XS_CBitcoin__CBHD_exportAddressFromCBHDKey, file);
        newXS("CBitcoin::CBHD::newWIF", XS_CBitcoin__CBHD_newWIF, file);
        newXS("CBitcoin::CBHD::publickeyFromWIF", XS_CBitcoin__CBHD_publickeyFromWIF, file);
        newXS("CBitcoin::CBHD::addressFromPublicKey", XS_CBitcoin__CBHD_addressFromPublicKey, file);
        newXS("CBitcoin::CBHD::createWIF", XS_CBitcoin__CBHD_createWIF, file);
#if (PERL_REVISION == 5 && PERL_VERSION >= 9)
  if (PL_unitcheckav)
       call_list(PL_scopestack_ix, PL_unitcheckav);
#endif
    XSRETURN_YES;
}

