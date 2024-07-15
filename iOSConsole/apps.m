//
//  apps.c
//  iOSConsole
//
//  Created by Samantha Marshall on 1/4/14.
//  Copyright (c) 2014 Samantha Marshall. All rights reserved.
//

#ifndef iOSConsole_apps_c
#define iOSConsole_apps_c

#include "apps.h"
#include "SDMMobileDevice.h"
#include <CoreFoundation/CoreFoundation.h>
#include "attach.h"
#include "Core.h"

void LookupAppsOnDevice(char *udid)
{
    SDMMD_AMDevice *device = FindDeviceFromUDID(udid);
    if (device)
    {
        sdmmd_return_t result = SDMMD_AMDeviceConnect(device);
        if (SDM_MD_CallSuccessful(result))
        {
            result = SDMMD_AMDeviceStartSession(device);
            if (SDM_MD_CallSuccessful(result))
            {
                CFDictionaryRef response;

                CFArrayRef lookupValues = SDMMD_ApplicationLookupDictionary();
                NSMutableDictionary *optionsDict = [NSMutableDictionary dictionary];
                optionsDict[@"ReturnAttributes"] = (__bridge id _Nullable)(lookupValues);

                result = SDMMD_AMDeviceLookupApplications(device, (__bridge CFDictionaryRef)(optionsDict), &response);
                if (SDM_MD_CallSuccessful(result))
                {
                    CFIndex keyCount = CFDictionaryGetCount(response);
                    Pointer keys[keyCount];
                    Pointer values[keyCount];
                    CFDictionaryGetKeysAndValues(response, PtrCast(keys, const void **),
                        PtrCast(values, const void **));
                    for (CFIndex appIndex = 0; appIndex < keyCount; appIndex++)
                    {
                        CFStringRef key = PtrCast(keys[appIndex], CFStringRef);
                        CFTypeRef value = PtrCast(values[appIndex], CFTypeRef);

                        CFShow(key);

                        bool hasSigningIdentity = false;
                        CFStringRef signingIdentity = NULL;
                        bool wasInstalledFromStore = false;
                        CFIndex appKeyCount = CFDictionaryGetCount(value);
                        Pointer appKeys[appKeyCount];
                        Pointer appValues[appKeyCount];
                        CFDictionaryGetKeysAndValues(value, PtrCast(appKeys, const void **),
                            PtrCast(appValues, const void **));
                        for (CFIndex appKeyIndex = 0; appKeyIndex < appKeyCount; appKeyIndex++)
                        {
                            CFStringRef appKey = PtrCast(appKeys[appKeyIndex], CFStringRef);
                            CFTypeRef appValue = PtrCast(appValues[appKeyIndex], CFTypeRef);

                            if (CFStringCompare(appKey, CFSTR(kAppLookupKeySignerIdentity), 0) == 0)
                            {
                                hasSigningIdentity = true;
                                signingIdentity = appValue;
                            }

                            if (CFStringCompare(appKey, CFSTR(kAppLookupKeyApplicationDSID), 0) == 0)
                            {
                                wasInstalledFromStore = true;
                            }
                        }

                        if (hasSigningIdentity)
                        {
                            if (wasInstalledFromStore)
                            {
                                CFShow(CFSTR("This app was installed from the App Store"));
                            }
                            else
                            {
                                if (CFStringCompare(signingIdentity,
                                    CFSTR("Apple iPhone OS Application Signing"), 0) != 0)
                                {
                                    CFShow(CFSTR("This app was installed by a developer"));
                                }
                            }
                        }

                        PrintCFDictionary(value);

                        NSMutableDictionary *appOptionsDict = [NSMutableDictionary dictionary];
                        appOptionsDict[@"ReturnAttributes"] = @[@kAppLookupKeyCFBundleIdentifier, @"SequenceNumber"];
                        appOptionsDict[@"com.apple.mobile_installation.metadata"] = @(YES);
                        appOptionsDict[@"BundleIDs"] = (__bridge id _Nullable)(key);

                        CFDictionaryRef appResponse;
                        result = SDMMD_AMDeviceLookupAppInfo(device, (__bridge CFDictionaryRef)(appOptionsDict), &appResponse);
                        if (SDM_MD_CallSuccessful(result))
                        {
                            PrintCFDictionary(appResponse);
                        }
                        CFShow(CFSTR("========================================="));
                    }
                }
                SDMMD_AMDeviceStopSession(device);
            }
            SDMMD_AMDeviceDisconnect(device);
        }
    }
}

#endif
