/*
 *  SDMUSBmuxListener.c
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

#ifndef _SDM_MD_USBMUXLISTENER_C_
#define _SDM_MD_USBMUXLISTENER_C_

#include "SDMMD_USBMuxListener.h"
#include "SDMMD_AMDevice_Internal.h"
#include "SDMMD_MCP.h"
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <sys/un.h>
#include <Core/Core.h>

#import "USBMuxResponseCode.h"
//#import "UsbMuxPacketListDevices.h"
#import "UsbMuxPacketListen.h"
#import "UsbMuxPacketConnect.h"

void SDMMD_USBMuxSend(uint32_t sock, USBMuxPacket *packet);
void SDMMD_USBMuxReceive(uint32_t sock, USBMuxPacket **aPacket);

uint32_t SDMMD_ConnectToUSBMux(time_t recvTimeoutSec);

@interface SDMMD_USBMuxListener()

@property (strong) NSMutableArray *responses;
@property (strong) NSArray *deviceList;

@property (readwrite) BOOL isActive;

@end

@implementation SDMMD_USBMuxListener
{
    uint32_t                _socket;
    dispatch_queue_t        _operationQueue;
    dispatch_queue_t        _socketQueue;
    dispatch_source_t       _socketSource;
    dispatch_semaphore_t    _semaphore;
}

+ (SDMMD_USBMuxListener *)sharedInstance
{
    static SDMMD_USBMuxListener *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        sharedInstance = [[SDMMD_USBMuxListener alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _socket = -1;
        self.isActive = NO;
        _operationQueue = dispatch_queue_create("com.samdmarshall.sdmmobiledevice.usbmux-operation-queue",
            DISPATCH_QUEUE_SERIAL);
        _socketQueue = dispatch_queue_create("com.samdmarshall.sdmmobiledevice.socketQueue", NULL);
        self.responses = [NSMutableArray array];
        self.deviceList = [NSArray array];
    }
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
    {
        return YES;
    }
    else if (![super isEqual:other])
    {
        return NO;
    }
    else
    {
        SDMMD_USBMuxListener *listener = (SDMMD_USBMuxListener *)other;
        return _socket == listener->_socket;
    }
}

- (NSUInteger)hash
{
    return _socket;
}

- (void)dealloc
{
    self.isActive = NO;
    Safe(close, _socket);
//    Safe(dispatch_release, _socketQueue);
    dispatch_async(dispatch_get_main_queue(),
    ^{
        CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
            (__bridge CFStringRef)kSDMMD_USBMuxListenerStoppedListenerNotification, NULL, NULL, true);
    });
}

#pragma mark -

- (void)responseCallback:(USBMuxPacket *)packet
{
    if (packet.payload)
    {
        USBMuxResponseCode *response = [[USBMuxResponseCode alloc] initWithDictionary:packet.payload];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                if (response.code)
                {
                    NSLog(@"usbmuxd returned%s: %lu - %@.\n",
                        (response.code ? " error" : ""), (unsigned long)response.code,
                        (response.string ? response.string :
                        @"Unknown Error Description"));
                }
            });
        // Signal that a response was received, see SDMMD_USBMux_Protocol.c
        dispatch_semaphore_signal(_semaphore);
    }
}

- (void)logsCallback:(USBMuxPacket *)packet
{
    dispatch_semaphore_signal(_semaphore);
}

- (void)deviceListCallback:(USBMuxPacket *)packet
{
    NSArray *devices = packet.payload[@"DeviceList"];
    for (NSDictionary *properties in devices)
    {
        SDMMD_AMDevice *deviceFromList = SDMMD_AMDeviceCreateFromProperties(properties);

        if (deviceFromList && ![self.deviceList containsObject:deviceFromList])
        {
            USBMuxPacket *devicePacket = [[USBMuxPacket alloc] initWithPayload:properties];
            [self attachedCallback:devicePacket];
        }
    }
    dispatch_semaphore_signal(_semaphore);
}

- (void)attachedCallback:(USBMuxPacket *)packet
{
    SDMMD_AMDevice* newDevice = SDMMD_AMDeviceCreateFromProperties(packet.payload);
    if (newDevice && ![self.deviceList containsObject:newDevice])
    {
        NSMutableArray *updateWithNew = [NSMutableArray arrayWithArray:self.deviceList];

        // give priority to usb over wifi
        if (newDevice.connection_type == kAMDeviceConnectionTypeUSB)
        {
            [updateWithNew addObject:newDevice];
            dispatch_async(dispatch_get_main_queue(),
            ^{
                CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                    (__bridge CFStringRef)kSDMMD_USBMuxListenerDeviceAttachedNotification, NULL, NULL, true);
            });

            self.deviceList = updateWithNew;
        }
        else if (newDevice.connection_type == kAMDeviceConnectionTypeWiFi)
        {
            // wifi
        }
    }

    dispatch_async(dispatch_get_main_queue(),
    ^{
        CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
            (__bridge CFStringRef)kSDMMD_USBMuxListenerDeviceAttachedNotificationFinished, NULL, NULL, true);
    });
}

- (void)listCallback:(USBMuxPacket *)packet
{
    dispatch_semaphore_signal(_semaphore);
}

- (void)unknownCallback:(USBMuxPacket *)packet
{
    printf("Unknown response from usbmuxd!\n");
    if (packet.payload)
    {
        NSLog(@"%@", packet.payload);
    }
    dispatch_semaphore_signal(_semaphore);
}

- (void)detachedCallback:(USBMuxPacket *)packet
{
    uint32_t detachedId = [(NSNumber *)packet.payload[@"DeviceID"] unsignedIntValue];

    NSMutableArray *updateWithRemove = [NSMutableArray arrayWithArray:self.deviceList];

    for (SDMMD_AMDevice *detachedDevice in self.deviceList)
    {
        // add something for then updating to use wifi if available.
        if (detachedId == SDMMD_AMDeviceGetConnectionID(detachedDevice))
        {
            [updateWithRemove removeObject:detachedDevice];

            dispatch_async(dispatch_get_main_queue(),
            ^{
                CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                    (__bridge CFStringRef)kSDMMD_USBMuxListenerDeviceDetachedNotification, NULL, NULL, true);
            });
        }
    }

    self.deviceList = [NSArray arrayWithArray:updateWithRemove];

    dispatch_async(dispatch_get_main_queue(),
    ^{
        CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
            (__bridge CFStringRef)kSDMMD_USBMuxListenerDeviceDetachedNotificationFinished, NULL, NULL, true);
    });
}

- (void)listenerListCallback:(USBMuxPacket *)packet
{
    dispatch_semaphore_signal(_semaphore);
}

#pragma mark -

- (void)updateDeviceList
{
    USBMuxPacket *devicesPacket = [[USBMuxPacket alloc] initWithType:kSDMMD_USBMuxPacketListDevicesType payload:nil];
    [[SDMMD_USBMuxListener sharedInstance] send:&devicesPacket];
}

#pragma mark -

- (void)start
{
    __block uint64_t bad_packet_counter = 0;
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        // no timeout for recv
        _socket = SDMMD_ConnectToUSBMux(0);
        _socketSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _socket, 0, _socketQueue);
        dispatch_source_set_event_handler(_socketSource,
        ^{
            //printf("socketSourceEventHandler: fired\n");

            // Allocate and receive packet
            USBMuxPacket *packet = nil;
            SDMMD_USBMuxReceive(self->_socket, &packet);

            // Validate packet payload
            if (packet.payload != nil)
            {
                if ([[packet.payload allKeys] containsObject:@"MessageType"])
                {
                    NSString *type = packet.payload[@"MessageType"];
                    if ([type isEqualToString:SDMMD_USBMuxPacketMessage(kSDMMD_USBMuxPacketResultType)])
                    {
                        // Packet ownership transfered to response handler
                        [self.responses addObject:packet];
                        [self responseCallback:packet];
                    }
                    else if ([type isEqualToString:SDMMD_USBMuxPacketMessage(kSDMMD_USBMuxPacketAttachType)])
                    {
                        [self attachedCallback:packet];
                        // Destroy received packet
                    }
                    else if ([type isEqualToString:SDMMD_USBMuxPacketMessage(kSDMMD_USBMuxPacketDetachType)])
                    {
                        [self detachedCallback:packet];
                        // Destroy received packet
                    }
                }
                else
                {
                    // Packet ownership transfered to response handler
                    [self.responses addObject:packet];
                    if ([[packet.payload allKeys] containsObject:@"Logs"])
                    {
                        [self logsCallback:packet];
                    }
                    else if ([[packet.payload allKeys] containsObject:@"DeviceList"])
                    {
                        [self deviceListCallback:packet];
                    }
                    else if ([[packet.payload allKeys] containsObject:@"ListenerList"])
                    {
                        [self listenerListCallback:packet];
                    }
                    else
                    {
                        [self unknownCallback:packet];
                    }
                }
            }
            else if (packet.bodyLength == 0)
            {
                // ignore this zero length packet
                // Destroy received packet
            }
            else
            {
                bad_packet_counter++;
                printf("%s: failed to decode CFPropertyList from packet payload\n",__FUNCTION__);
                if (bad_packet_counter > 10)
                {
                    printf("eating bad packets, exiting...\n");
                    exit(EXIT_FAILURE);
                }
                // Destroy received packet
            }
        });

        dispatch_source_set_cancel_handler(_socketSource,
        ^{
            printf("%s: source canceled\n",__FUNCTION__);
        });

        dispatch_resume(_socketSource);

        while (!self.isActive)
        {
            USBMuxPacket *startListen = [[USBMuxPacket alloc] initWithType:kSDMMD_USBMuxPacketListenType payload:nil];
            [self send:&startListen];
            if (startListen.payload)
            {
                USBMuxResponseCode *response = [[USBMuxResponseCode alloc] initWithDictionary:startListen.payload];
                if (response.code == 0)
                {
                    self.isActive = true;
                }
                else
                {
                    NSLog(@"%s: non-zero response code. trying again. code:%lu string:%@\n",
                          __FUNCTION__, (unsigned long)response.code, response.string ? response.string : @"");
                }
            }
            else
            {
                printf("%s: no response payload. trying again.\n",__FUNCTION__);
            }
        }
    });
}

- (void)send:(USBMuxPacket **)packet
{
    __block USBMuxPacket *block_packet = *packet;

    dispatch_sync(_operationQueue,
    ^{
        // This semaphore will be signaled when a response is received
        _semaphore = dispatch_semaphore_create(0);

        // Send the outgoing packet
        SDMMD_USBMuxSend(_socket, block_packet);

        // Wait for a response-type packet to be received
        dispatch_semaphore_wait(_semaphore, block_packet.timeout);

        // Search responses for a packet that matches the one sent
        USBMuxPacket *responsePacket = nil;

        for (USBMuxPacket *response in self.responses)
        {
            if (block_packet.bodyTag == response.bodyTag)
            {
                // Each matching packet is removed from the responses list
                responsePacket = response;
                break;
            }
        }

        if (responsePacket)
        {
            [self.responses removeObject:responsePacket];
        }

        if (responsePacket == nil)
        {
            // Didn't find an appropriate response, initialize an empty packet to return
            responsePacket = [[USBMuxPacket alloc] init];
        }

        // Destroy sent packet

        // Return response packet to caller
        block_packet = responsePacket;

        // Discard "waiting for response" semaphore
//        dispatch_release(_semaphore);
    });

    *packet = block_packet;
}

- (void)receive:(USBMuxPacket **)packet
{
    SDMMD_USBMuxReceive(_socket, packet);
}

@end

/*
 debugging traffic:
 sudo mv /var/run/usbmuxd /var/run/usbmuxx
 sudo socat -t100 -x -v UNIX-LISTEN:/var/run/usbmuxd,mode=777,reuseaddr,fork UNIX-CONNECT:/var/run/usbmuxx
 */
uint32_t SDMMD_ConnectToUSBMux(time_t recvTimeoutSec)
{
    int result = 0;

    // Initialize socket
    uint32_t sock = socket(AF_UNIX, SOCK_STREAM, 0);

    if (recvTimeoutSec != 0)
    {
        struct timeval timeout = {.tv_sec = recvTimeoutSec, .tv_usec = 0};
        if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)))
        {
            int err = errno;
            printf("%s: setsockopt SO_RCVTIMEO failed: %d - %s\n", __FUNCTION__, err, strerror(err));
        }
    }

    // Set send/receive buffer sizes
    uint32_t bufSize = 0x00010400;
    if (!result)
    {
        setsockoptCond(sock, SOL_SOCKET, SO_SNDBUF, bufSize, {result = 1; });
    }

    if (!result)
    {
        setsockoptCond(sock, SOL_SOCKET, SO_RCVBUF, bufSize, {result = 2; });
    }

    if (!result)
    {
        uint32_t noPipe = 1; // Disable SIGPIPE on socket i/o error
        setsockoptCond(sock, SOL_SOCKET, SO_NOSIGPIPE, noPipe, {result = 3; });
    }

    if (!result)
    {
        // Create address structure to point to usbmuxd socket
        char *mux = "/var/run/usbmuxd";
        struct sockaddr_un address;
        address.sun_family = AF_UNIX;
        strncpy(address.sun_path, mux, sizeof(address.sun_path));
        address.sun_len = SUN_LEN(&address);

        // Connect socket
        if (connect(sock, (const struct sockaddr *)&address, sizeof(struct sockaddr_un)))
        {
            result = 4;
            int err = errno;
            printf("%s: connect socket failed: %d - %s\n", __FUNCTION__, err, strerror(err));
        }
    }

    if (!result)
    {
        // Set socket to blocking IO mode
        uint32_t nonblock = 0;
        if (ioctl(sock, FIONBIO, &nonblock))
        {
            result = 5;
            int err = errno;
            printf("%s: ioctl FIONBIO failed: %d - %s\n", __FUNCTION__, err, strerror(err));
        }
    }

    if (result)
    {
        // Socket creation failed
        close(sock);
        sock = -1;
    }

    return sock;
}

sdmmd_return_t SDMMD_USBMuxConnectByPort(SDMMD_AMDevice *device, uint32_t port, uint32_t *socketConn)
{
    sdmmd_return_t result = kAMDMuxConnectError;
    // 10-sec recv timeout
    *socketConn = SDMMD_ConnectToUSBMux(10);
    if (*socketConn)
    {
        // Requesting socket connection for specified port number
        USBMuxPacket *connect = [[USBMuxPacket alloc] initWithType:kSDMMD_USBMuxPacketConnectType
            payload:
            @{
                @"DeviceID" : @(device.device_id),
                @"PortNumber": @(port)
            }];


        SDMMD_USBMuxSend(*socketConn, connect);

        USBMuxPacket *response = [[USBMuxPacket alloc] init];
        SDMMD_USBMuxReceive(*socketConn, &response);

        // Check response for success, on failure result will be kAMDMuxConnectError
        if (response.payload)
        {
            NSString *msgType = nil;
            if ((msgType = [response.payload objectForKey:@"MessageType"]) && [msgType isEqualToString:@"Result"])
            {
                NSNumber *msgResult = nil;
                if ((msgResult = [response.payload objectForKey:@"Number"]) && msgResult.integerValue == kAMDSuccess)
                {
                    // Socket negotiation successful
                    result = kAMDSuccess;
                }
            }
        }
    }
    return result;
}

#endif
