//
//  main.h
//  cbitcoin
//
//  Created by Matthew Mitchell on 11/12/2013.
//  Copyright (c) 2013 Matthew Mitchell
//
//  This file is part of cbitcoin. It is subject to the license terms
//  in the LICENSE file found in the top-level directory of this
//  distribution and at http://www.cbitcoin.com/license.html. No part of
//  cbitcoin, including this file, may be copied, modified, propagated,
//  or distributed except according to the terms contained in the
//  LICENSE file.

#include <stdio.h>
#include <ctype.h>
#include <openssl/ssl.h>
#include <openssl/ripemd.h>
#include <openssl/rand.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <arpa/inet.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/epoll.h>
#include <mqueue.h>
#include <netdb.h>
#include <sys/time.h>
#include <pwd.h>

#include <CBDependencies.h>
#include <CBVersion.h>
#include <CBPeer.h>
#include <CBNetworkAddress.h>

// Macros
#define CB_DEFUALT_DATA_DIR "/.cbitcoin-server"


int spv_dummy(void);



CBVersionServices spv_ConvertStringToVersionServices(char* service);

CBNetworkAddress * spv_CreateAddress(uint64_t lastSeen, CBSocketAddress addr, char* services, int isPublicint);
