//
//  attach.h
//  iOSConsole
//
//  Created by Samantha Marshall on 1/4/14.
//  Copyright (c) 2014 Samantha Marshall. All rights reserved.
//

#ifndef iOSConsole_attach_h
#define iOSConsole_attach_h

#include <CoreFoundation/CoreFoundation.h>
#include "SDMMobileDevice.h"

SDMMD_AMDevice *FindDeviceFromUDID(char *udid);
SDMMD_AMConnectionRef AttachToDeviceAndService(SDMMD_AMDevice *device, char *service);

#endif
