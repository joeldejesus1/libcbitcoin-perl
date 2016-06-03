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

SV* picocoin_returnblankSV(void){
	//SV* ans_sv = newSVpv("",1);
	//return ans_sv;
	return &PL_sv_undef;
}


int dummy2(int x) {
	return x;
}

static bool is_digitstr(const char *s)
{
	if (*s == '-')
		s++;

	while (*s) {
		if (!isdigit(*s))
			return false;
		s++;
	}

	return true;
}

static char **strsplit_set(const char *s, const char *delim)
{
	// init delimiter lookup table
	const char *stmp;
	bool is_delim[256];
	memset(&is_delim, 0, sizeof(is_delim));

	stmp = delim;
	while (*stmp) {
		is_delim[(unsigned char)*stmp] = true;
		stmp++;
	}

	bool in_str = true;
	parr *pa = parr_new(0, free);
	cstring *cs = cstr_new(NULL);
	if (!pa || !cs)
		goto err_out;

	while (*s) {
		unsigned char ch = (unsigned char) *s;
		if (is_delim[ch]) {
			if (in_str) {
				in_str = false;
				parr_add(pa, cs->str);

				cstr_free(cs, false);
				cs = cstr_new(NULL);
				if (!cs)
					goto err_out;
			}
		} else {
			in_str = true;
			if (!cstr_append_c(cs, ch))
				goto err_out;
		}
		s++;
	}

	parr_add(pa, cs->str);
	cstr_free(cs, false);

	parr_add(pa, NULL);

	char **ret = (char **) pa->data;
	parr_free(pa, false);


	return ret;

err_out:
	parr_free(pa, true);
	cstr_free(cs, true);
	return NULL;
}

static void freev(void *vec_)
{
	void **vec = vec_;
	if (!vec)
		return;

	unsigned int idx = 0;
	while (vec[idx]) {
		free(vec[idx]);
		vec[idx] = NULL;
		idx++;
	}

	free(vec);
}

// from libtest.c
cstring *parse_script_str(const char *enc)
{
	char **tokens = strsplit_set(enc, " \t\n");
	assert (tokens != NULL);

	cstring *script = cstr_new_sz(64);

	unsigned int idx;
	for (idx = 0; tokens[idx] != NULL; idx++) {
		char *token = tokens[idx];

		if (is_digitstr(token)) {
			int64_t v = strtoll(token, NULL, 10);
			bsp_push_int64(script, v);
		}

		else if (is_hexstr(token, true)) {
			cstring *raw = hex2str(token);
			cstr_append_buf(script, raw->str, raw->len);
			cstr_free(raw, true);
		}

		else if ((strlen(token) >= 2) &&
			 (token[0] == '\'') &&
			 (token[strlen(token) - 1] == '\''))
			bsp_push_data(script, &token[1], strlen(token) - 2);

		else if (GetOpType(token) != ccoin_OP_INVALIDOPCODE)
			bsp_push_op(script, GetOpType(token));

		else{
			//assert(!"parse error");
			freev(tokens);
			cstr_free(script, true);
			return NULL;
		}
			
	}

	freev(tokens);

	return script;
}

///////// picocoin

// change binary to string
SV* picocoin_script_decode(SV* x){
	STRLEN len; //calculated via SvPV
	char * scriptSigEnc = (char*) SvPV(x,len);
	cstring *scriptSig = parse_script_str(scriptSigEnc);
	if(scriptSig == NULL){
		return picocoin_returnblankSV();
	}
	
	int length = (scriptSig->len)*sizeof(uint8_t);
	uint8_t * answer = malloc(length);
	//sprintf("%s",ans->str);
	memcpy(answer,scriptSig->str,length);
	SV* ans_sv = newSVpv(answer,length);
	cstr_free(scriptSig, true);
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



// const char *opn = GetOpName(OP_PUBKEY);

AV* picocoin_parse_script(SV* serialized_script){
	AV *r = newAV();
	
	STRLEN len; //calculated via SvPV
	uint8_t * spointer = (uint8_t*) SvPV(serialized_script,len);
	struct const_buffer buf = { spointer, len };
	struct bscript_parser bp;
	struct bscript_op op;
	//parr *arr = parr_new(16, free);

	
	bsp_start(&bp, &buf);
	// const char *GetOpName(enum opcodetype opcode_)
	while (bsp_getop(&op, &bp)){
		//parr_add(arr, memdup(&op, sizeof(op)));
		struct bscript_op *op_p;
		op_p = memdup(&op, sizeof(op));
		// av_push( r, newSVnv());
		if (is_bsp_pushdata(op_p->op)) {
			//uint8_t * d1 = malloc(op_p->data.len * sizeof(uint8_t));
			//memcpy(d1,op_p->data.p,op_p->data.len);
			
			char * data_withnull = malloc(2*op_p->data.len*sizeof(char) + 1 + 2);
			char * data_withoutnull = malloc(2*op_p->data.len*sizeof(char) + 1 + 2 - 1);
			
			uint8_t lendata[1];
			lendata[0] = (uint8_t) op_p->data.len;
			
			char * datalen = malloc(2 * 1 + 1);
			datalen[0] = '0';
			datalen[1] = 'x';
			encode_hex(datalen + 2, lendata, 1);
			av_push( r, newSVpv(datalen,  4 ));
			
			//memcpy(data, hexprefix, hexprefix_length);
			data_withnull[0] = '0';
			data_withnull[1] = 'x';
			encode_hex(data_withnull + 2, op_p->data.p, op_p->data.len);
			
			// strip the null out
			int i;
			for(i=0;i<2*op_p->data.len*sizeof(char) + 1 + 2 - 1;i++){
				data_withoutnull[i] = data_withnull[i];
			}
			free(data_withnull);
			av_push( r, newSVpv(data_withoutnull,  2*op_p->data.len*sizeof(char) + 1 + 2 - 1 ));
		} else {
			const char* ox1 = GetOpName(op_p->op);
			size_t length = strlen(ox1);
			char * opname = malloc(length * sizeof(char));
			// max size is 100
			strncpy(opname,ox1,length);
			av_push( r, newSVpv(opname,length));
		}
		free(op_p);
	}
	
	
	if (bp.error){
		av_push( r,  newSViv(0)   );
	}
	else{
		av_push( r,  newSViv(1)   );
	}

	return r;

err_out:
	//parr_free(arr, true);
	return r;
}



MODULE = CBitcoin::Script	PACKAGE = CBitcoin::Script


PROTOTYPES: DISABLED

int
dummy2(x)
	int x
	
SV*
picocoin_script_decode(x)
	SV* x

AV*
picocoin_parse_script(x)
	SV* x
