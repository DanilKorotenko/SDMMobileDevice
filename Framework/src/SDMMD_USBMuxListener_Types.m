/*
 *  SDMMD_USBmuxListener_Types.c
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

#include <CoreFoundation/CoreFoundation.h>
#include "SDMMD_USBMuxListener_Types.h"

NSString *kSDMMD_USBMuxListenerDeviceAttachedNotification = @"SDMMD_USBMuxListenerDeviceAttachedNotification";
NSString *kSDMMD_USBMuxListenerDeviceAttachedNotificationFinished = @"SDMMD_USBMuxListenerDeviceAttachedNotificationFinished";
NSString *kSDMMD_USBMuxListenerDeviceDetachedNotification = @"SDMMD_USBMuxListenerDeviceDetachedNotification";
NSString *kSDMMD_USBMuxListenerDeviceDetachedNotificationFinished = @"SDMMD_USBMuxListenerDeviceDetachedNotificationFinished";
NSString *kSDMMD_USBMuxListenerStoppedListenerNotification = @"SDMMD_USBMuxListenerStoppedListenerNotification";

NSString *SDMMD_USBMuxPacketMessage(SDMMD_USBMuxPacketMessageType aType)
{
    switch (aType)
    {
        case kSDMMD_USBMuxPacketInvalidType: return @"Invalid";
        case kSDMMD_USBMuxPacketConnectType: return @"Connect";
        case kSDMMD_USBMuxPacketListenType: return @"Listen";
        case kSDMMD_USBMuxPacketResultType: return @"Result";
        case kSDMMD_USBMuxPacketAttachType: return @"Attached";
        case kSDMMD_USBMuxPacketDetachType: return @"Detached";
        case kSDMMD_USBMuxPacketLogsType: return @"Logs";
        case kSDMMD_USBMuxPacketListDevicesType: return @"ListDevices";
        case kSDMMD_USBMuxPacketListListenersType: return @"ListListeners";
        case kSDMMD_USBMuxPacketReadBUIDType: return @"ReadBUID";
        case kSDMMD_USBMuxPacketReadPairRecordType: return @"ReadPairRecord";
        case kSDMMD_USBMuxPacketSavePairRecordType: return @"SavePairRecord";
        case kSDMMD_USBMuxPacketDeletePairRecordType: return @"DeletePairRecord";

        default:
            break;
    }
    return nil;
}
