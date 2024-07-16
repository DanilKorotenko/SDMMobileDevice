//
//  power.c
//  iOSConsole
//
//  Created by Samantha Marshall on 1/25/14.
//  Copyright (c) 2014 Samantha Marshall. All rights reserved.
//

#ifndef iOSConsole_power_c
#define iOSConsole_power_c

#include "power.h"
#include "Core.h"
#include "attach.h"
#include "SDMMobileDevice.h"
#include "SDMMD_Service.h"
#include "SDMMD_Connection_Internal.h"
#import "DeviceMessage.h"

void SendDeviceCommand(char *udid, NSDictionary *request)
{
    SDMMD_AMDevice *device = FindDeviceFromUDID(udid);
    if (device)
    {
        SDMMD_AMConnectionRef powerDiag = AttachToDeviceAndService(device, AMSVC_DIAG_RELAY);
        if (request)
        {
            SocketConnection socket = SDMMD_TranslateConnectionToSocket(powerDiag);
            sdmmd_return_t result = SDMMD_ServiceSendMessage(socket, request);
            if (SDM_MD_CallSuccessful(result))
            {
                NSString *command = request[@"Request"];
                NSLog(@"Sent %@ command to device, this could take up to 5 seconds.\n", command);
                CFDictionaryRef response;
                result = SDMMD_ServiceReceiveMessage(socket, PtrCast(&response, CFPropertyListRef *));
                if (SDM_MD_CallSuccessful(result))
                {
                    PrintCFDictionary(response);
                }
            }
        }
    }
}

void SendSleepToDevice(char *udid)
{
    NSMutableDictionary *request = SDMMD__CreateRequestDict(@"Sleep");
    SendDeviceCommand(udid, request);
}

void SendRebootToDevice(char *udid)
{
    NSMutableDictionary *request = SDMMD__CreateRequestDict(@"Restart");
    request[@"DisplayPass"] = @(YES);
    request[@"WaitForDisconnect"] = @(NO);
    SendDeviceCommand(udid, request);
}

void SendShutdownToDevice(char *udid)
{
    NSMutableDictionary *request = SDMMD__CreateRequestDict(@"Shutdown");
    request[@"DisplayPass"] = @(YES);
    request[@"WaitForDisconnect"] = @(NO);
    SendDeviceCommand(udid, request);
}

#endif
