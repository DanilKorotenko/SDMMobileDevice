/*
 *  SDMMD_AMDevice_Class_Internal.h
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

#ifndef SDMMobileDevice_Framework_SDMMD_AMDevice_Internal_h
#define SDMMobileDevice_Framework_SDMMD_AMDevice_Internal_h

#include <CoreFoundation/CoreFoundation.h>
#include <SDMMobileDevice/CFRuntime.h>
#include <openssl/ssl.h>
#include <SDMMobileDevice/SDMMD_Error.h>

// Everything below here you shouldn't be calling, this is internal for the library
//=================================================================================
sdmmd_return_t SDMMD__CopyEscrowBag(SDMMD_AMDevice *device, CFDataRef *bag);

SSL *SDMMD_lockssl_handshake(uint64_t socket, CFTypeRef hostCert, CFTypeRef deviceCert, CFTypeRef hostPrivKey, uint32_t num);
sdmmd_return_t SDMMD__connect_to_port(SDMMD_AMDevice *device, uint32_t port, bool hasTimeout, uint32_t *socketConn, bool isSSL);

sdmmd_return_t SDMMD_lockconn_send_message(SDMMD_AMDevice *device, CFDictionaryRef dict);
sdmmd_return_t SDMMD_lockconn_receive_message(SDMMD_AMDevice *device, CFMutableDictionaryRef *dict);

#endif
