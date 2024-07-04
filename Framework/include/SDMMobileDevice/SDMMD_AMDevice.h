/*
 *  SDMMD_AMDevice.h
 *  SDMMobileDevice
 *
 * Copyright (c) 2014, Samantha Marshall
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
 * following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer
 * 		in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of Samantha Marshall nor the names of its contributors may be used to endorse or promote products derived from this
 * 		software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef _SDM_MD_ADMDEVICE_H_
#define _SDM_MD_ADMDEVICE_H_

#import <Foundation/Foundation.h>

#include <SDMMobileDevice/SDMMD_Error.h>
#include <SDMMobileDevice/SDMMD_Keys.h>
/* Private
 #include "SDMMD_MRecoveryModeDevice.h"
 #include "SDMMD_MRUSBDevice.h"
 #include "SDMMD_MDFUModeDevice.h"
 #include "SDMMD_MRestoreModeDevice.h"
 #include "SDMMD_MRestorableDevice.h"
 */
#include <SDMMobileDevice/SDMMD_Types.h>

typedef enum _AMDInterfaceConnectionType
{
    kAMDInterfaceConnectionTypeInvalid = -1,
    kAMDInterfaceConnectionTypeUnknown = 0,
    kAMDInterfaceConnectionTypeDirect = 1,
    kAMDInterfaceConnectionTypeIndirect = 2
} AMDInterfaceConnectionType;
typedef AMDInterfaceConnectionType sdmmd_interface_return_t;

enum
{
    kAMDeviceConnectionTypeWiFi = 0,
    kAMDeviceConnectionTypeUSB = 1,
};
typedef int32_t AMDeviceConnectionType;

@interface SDMMD_AMDevice : NSObject

@property (readwrite, atomic)   int32_t device_id;
@property (strong)              NSString *unique_device_id;
@property (readwrite)           BOOL device_active;
@property (strong)              NSString *session; // needs to be not zero in AMDeviceSecureStartService  -- connection
@property (readwrite)           AMDeviceConnectionType connection_type;  // (1 for USB, 0 for WiFi)
@property (readwrite)           uint16_t product_id;
@property (readwrite)           int32_t location_id;
@property (strong)              NSData *network_address; // stores a sockaddr_storage
@property (strong)              NSString *service_name; // bonjour service name
@property (readwrite)           int32_t interface_index;
@property (readwrite)           pthread_mutex_t mutex_lock;

@property (readonly)            BOOL isLockDownConnectionNull;

@end

/*!
 @function SDMMD_AMDeviceCreateFromProperties
 @discussion
 Create and return a SDMMD_AMDevice* object from passed properties dictionary, this is used by the USBmuxd for creating devices when they are attached.
 @param dict
 CFDictionaryRef of the device properties, this is created by a USBmuxd callback.
 */
SDMMD_AMDevice *SDMMD_AMDeviceCreateFromProperties(NSDictionary *dict);

sdmmd_return_t SDMMD_AMDeviceActivate(SDMMD_AMDevice* device, CFDictionaryRef options);
sdmmd_return_t SDMMD_AMDeviceDeactivate(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceConnect
 @discussion
 Connect to a device, returns a code that will give an return status or error code.
 @param device
 The device object to connect to.
 */
sdmmd_return_t SDMMD_AMDeviceConnect(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceDisconnect
 @discussion
 Disconnect from a device, returns a code that will give an return status or error code.
 @param device
 The device object to disconnect from.
 */
sdmmd_return_t SDMMD_AMDeviceDisconnect(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceIsValid
 @discussion
 checks to see if a device is still an attached and valid device to use
 @param device
 device to check
 */
bool SDMMD_AMDeviceIsValid(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceValidatePairing
 @discussion
 Performs a check to see if a device pairing record is correct
 @param device
 device object validate the pairing record for
 */
sdmmd_return_t SDMMD_AMDeviceValidatePairing(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceIsPaired
 @discussion
 Returns if the passed device is paired with the host
 @param device
 device object to check if pairing record exists
 */
bool SDMMD_AMDeviceIsPaired(SDMMD_AMDevice* device);

// Pairing is fully tested and finished yet
sdmmd_return_t SDMMD_AMDevicePair(SDMMD_AMDevice* device);
sdmmd_return_t SDMMD_AMDevicePairWithOptions(SDMMD_AMDevice* device, CFDictionaryRef options);
sdmmd_return_t SDMMD_AMDeviceExtendedPairWithOptions(SDMMD_AMDevice* device, CFDictionaryRef options, CFDictionaryRef *extendedResponse);
sdmmd_return_t SDMMD_AMDeviceUnpair(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceStartSession
 @discussion
 starts a lockdown session on the device. this is necessary to start services and access some device key-value pairs.
 @param device
 device to start the session with
 */
sdmmd_return_t SDMMD_AMDeviceStartSession(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceStopSession
 @discussion
 stops a lockdown session on the device.
 @param device
 device to stop the session with
 */
sdmmd_return_t SDMMD_AMDeviceStopSession(SDMMD_AMDevice* device);

CFStringRef SDMMD_AMDeviceCopyUDID(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceUSBDeviceID
 @discussion
 returns the device identifier for a specific device, this is unique to the device's attached state. this changes between attaches. this is also used for associating connections to a specific device
 @param device
 device to get the device identifer of

 */
uint32_t SDMMD_AMDeviceUSBDeviceID(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceUSBLocationID
 @discussion
 returns the usb location identifier
 @param device
 device to get the usb location identifer of
 */
uint32_t SDMMD_AMDeviceUSBLocationID(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceUSBProductID
 @discussion
 returns the usb product identifier
 @param device
 device to get the usb product identifer of
 */
uint16_t SDMMD_AMDeviceUSBProductID(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceGetConnectionID
 @discussion
 returns the connection ID associated with a device
 @param device
 Device to get the connection ID of
 */
uint32_t SDMMD_AMDeviceGetConnectionID(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceIsAttached
 @discussion
 This is a sanity check to ensure that a specific device is still attached before performing an action.
 @param device
 Device to check if attached.
 */
bool SDMMD_AMDeviceIsAttached(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceCopyValue
 @discussion
 Fetchs data associated with a particular device key in a domain, see SDMMD_Keys.h for domain and key pairs
 @param device
 Device object to fetch key-value from
 @param domain
 CFStringRef of the domain name associated with a key, this can be NULL.
 @param key
 CFStringRef of the key of the value to be requested from the device.
 */
CFTypeRef SDMMD_AMDeviceCopyValue(SDMMD_AMDevice* device, CFStringRef domain, CFStringRef key);

/*!
 @function SDMMD_AMDeviceSetValue
 @discussion
 Sets data associated with a particular device key in a domain, see SDMMD_Keys.h for domain and key pairs
 @param device
 Device object to set key-value on
 @param domain
 CFStringRef of the domain name associated with a key, this can be NULL.
 @param key
 CFStringRef of the key of the value to be set on the device.
 @param value
 CFTypeRef of the value to be set on the device.
 */
sdmmd_return_t SDMMD_AMDeviceSetValue(SDMMD_AMDevice* device, CFStringRef domain, CFStringRef key, CFTypeRef value);

sdmmd_return_t SDMMD_AMDeviceMountImage(SDMMD_AMDevice* device, CFStringRef path, CFDictionaryRef dict, CallBack handle, void *unknown);

/*!
 @function SDMMD_GetSIMStatusCode
 @discussion
 returns a struct containing the SIM status code number and corresponding status string
 @param device
 device to check the SIM of
 */
sdmmd_sim_return_t SDMMD_GetSIMStatusCode(SDMMD_AMDevice* device);

/*!
 @function SDMMD_GetActivationStatus
 @discussion
 returns a struct containing the activation code number and status string
 @param device
 device to check activation status of
 */
sdmmd_activation_return_t SDMMD_GetActivationStatus(SDMMD_AMDevice* device);

/*!
 @function SDMMD_AMDeviceGetInterfaceType
 @discussion
 Get the interface type ie USB / WiFi.
 @param device
 The device to query
 */
sdmmd_interface_return_t SDMMD_AMDeviceGetInterfaceType(SDMMD_AMDevice* device);

#endif
