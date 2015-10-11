#include "spv.h"

int spv_dummy(void){
	return 1;
}






/*
 * Get Version to send on connection


CBVersion * spv_GetVersion(uint32_t timestamp,uint64_t services,char* addr_recv,){

	CBNetworkAddress * sourceAddr = CBNetworkCommunicatorGetOurMainAddress(self, addRecv->type);
}
*/




CBVersionServices spv_ConvertStringToVersionServices(char* service){
	char fullnode[] = "full node";
	if(strcmp(service,fullnode) == 0){
		return CB_SERVICE_FULL_BLOCKS;
	}
	else{
		return CB_SERVICE_NO_FULL_BLOCKS;
	}
}


CBNetworkAddress * spv_CreateAddress(uint64_t lastSeen, CBSocketAddress addr, char* services, int isPublicint){


	CBVersionServices version_services = spv_ConvertStringToVersionServices(services);




	bool isPublic;
	if(isPublicint > 0){
		isPublic = true;
	}
	else{
		isPublic = false;
	}

	return CBNewNetworkAddress(lastSeen,addr,version_services, isPublic);

}
