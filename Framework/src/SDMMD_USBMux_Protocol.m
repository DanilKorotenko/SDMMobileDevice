/*
 *  SDMMD_USBMux_Protocol.c
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

#ifndef _SDM_MD_USBMUX_PROTOCOL_C_
#define _SDM_MD_USBMUX_PROTOCOL_C_

#include "SDMMD_USBMuxListener.h"
#include <Core/Core.h>
#include <sys/socket.h>

void SDMMD_USBMuxSend(uint32_t sock, struct USBMuxPacket *packet);
void SDMMD_USBMuxReceive(uint32_t sock, struct USBMuxPacket *packet);


void SDMMD_USBMuxSend(uint32_t sock, struct USBMuxPacket *packet)
{
    NSError *error = nil;
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:packet->payload format:NSPropertyListXMLFormat_v1_0 options:0
        error:&error];

    char *buffer = (char *)malloc(xmlData.length);
    [xmlData getBytes:buffer length:xmlData.length];

    ssize_t result = send(sock, &packet->body, sizeof(struct USBMuxPacketBody), 0);
    if (result == sizeof(struct USBMuxPacketBody))
    {
        if (packet->body.length > result)
        {
            ssize_t payloadSize = packet->body.length - result;
            ssize_t remainder = payloadSize;
            while (remainder)
            {
                result = send(sock, &buffer[payloadSize - remainder], sizeof(char), 0);
                if (result != sizeof(char))
                {
                    break;
                }
                remainder -= result;
            }
        }
    }
}

void SDMMD_USBMuxReceive(uint32_t sock, struct USBMuxPacket *packet)
{
    ssize_t result = recv(sock, &packet->body, sizeof(struct USBMuxPacketBody), 0);
    if (result == sizeof(struct USBMuxPacketBody))
    {
        ssize_t payloadSize = packet->body.length - result;
        if (payloadSize)
        {
            char *buffer = calloc(1, payloadSize);
            ssize_t remainder = payloadSize;
            while (remainder)
            {
                result = recv(sock, &buffer[payloadSize - remainder], sizeof(char), 0);
                if (result != sizeof(char))
                {
                    break;
                }
                remainder -= result;
            }
            NSData *xmlData = [NSData dataWithBytes:buffer length:payloadSize];
            NSError *error = nil;
            packet->payload = [NSPropertyListSerialization propertyListWithData:xmlData options:NSPropertyListImmutable format:NULL
                error:&error];

            Safe(free, buffer);
        }
    }
}

#endif
