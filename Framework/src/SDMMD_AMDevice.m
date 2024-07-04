/*
 *  SDMMD_AMDevice.c
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

#ifndef _SDM_MD_AMDEVICE_C_
#define _SDM_MD_AMDEVICE_C_

// Ignore OS X SSL deprecation warnings
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#include "SDMMD_AMDevice.h"
#include "SDMMD_AMDevice_Internal.h"
#include "SDMMD_Connection_Private.h"
#include "SDMMD_Functions.h"
#include "SDMMD_Service.h"
#include "SDMMD_USBMuxListener.h"
#include <string.h>
#include <errno.h>
#include <openssl/bio.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/select.h>
#include <sys/time.h>
#include "CFRuntime.h"
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>
#include <Core/Core.h>
#include "SDMMD_Functions.h"
#include "SDMMD_AppleFileConduit.h"
#include "SDMMD_SSL_Functions.h"
#include "SDMMD_Error.h"
#import "SDMMD_lockdown_conn.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <mach/mach_port.h>

#include <netdb.h>

SDMMD_lockdown_conn *SDMMD_lockdown_connection_create(uint32_t socket);
sdmmd_return_t SDMMD_lockdown_connection_destory(SDMMD_lockdown_conn *lockdownCon);

@interface SDMMD_AMDevice ()

@property (strong)              SDMMD_lockdown_conn *lockdown_conn;

@end

@implementation SDMMD_AMDevice
{
    int16_t padding0;						 // 26
    int32_t unknown1;						 // 28
    int32_t unknown44;						 // 44
    unsigned char unknown7[3];				 // 141
    int64_t unknown8;						 // 144
    CFDataRef unknownData;					 // 152
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

- (void)dealloc
{
    self.unique_device_id = nil;

    if (self.lockdown_conn)
    {
        Safe(close, (uint32_t)self.lockdown_conn.connection);
        Safe(SSL_free, self.lockdown_conn.ssl);
        self.lockdown_conn = nil;
    }
    self.session = nil;
    self.service_name = nil;
    self.network_address = nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<SDMMD_AMDevice* %p>{device = %d}", self, self.device_id];
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
        SDMMD_AMDevice *otherDevice = (SDMMD_AMDevice *)other;

        BOOL result = (self.device_id == otherDevice.device_id);
        if (!result)
        {
            // evaluate for usb vs wifi
            result = [self.unique_device_id isEqualToString:otherDevice.unique_device_id];
        }
        return result;
    }
}

- (NSUInteger)hash
{
    return self.device_id;
}

#pragma mark -

- (BOOL)isLockDownConnectionNull
{
    return self.lockdown_conn == nil;
}

@end

uint64_t peer_certificate_data_index(void)
{
    static uint64_t data_index = 0;
    if (data_index == 0)
    {
        data_index = SDMMD_lockssl_init();
    }
    return data_index;
}

SDMMD_lockdown_conn *SDMMD_lockdown_connection_create(uint32_t socket)
{
    SDMMD_lockdown_conn *lockdown = [[SDMMD_lockdown_conn alloc] init];
    if (socket != 0)
    {
        lockdown.connection = socket;
//        Safe(free, lockdown->pointer);
        lockdown.length = 0;
    }
    return lockdown;
}

X509 *SDMMD__decode_certificate(CFDataRef cert)
{
    X509 *result = NULL;
    if (cert)
    {
        BIO *newBIO = SDMMD__create_bio_from_data(cert);
        if (newBIO == 0)
        {
            printf("%s: Could not create BIO from CFData.\n", __FUNCTION__);
        }
        else
        {
            result = PEM_read_bio_X509(newBIO, NULL, NULL, NULL);
            if (result == NULL)
            {
                printf("%s: PEM_read_bio_X509 failed.\n", __FUNCTION__);
            }
            Safe(BIO_free, newBIO);
        }
    }
    return result;
}

int SDMMD__ssl_verify_callback(int value, X509_STORE_CTX *store)
{
    bool result = true;
    X509 *cert = NULL, *decoded = NULL;
    //	if (value || (X509_STORE_CTX_get_error(store) + 0xffffffffffffffec < 0x2)) {
    if (value ||
        X509_STORE_CTX_get_error(store) == X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY ||
        X509_STORE_CTX_get_error(store) == X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE)
    {
        unsigned char *var_8 = NULL;
        unsigned char *var_16 = NULL;
        cert = X509_STORE_CTX_get_current_cert(store);
        if (cert)
        {
            SSL *storeSSL = (SSL *)X509_STORE_CTX_get_ex_data(store,
                SSL_get_ex_data_X509_STORE_CTX_idx());
            CFDataRef data = SSL_get_ex_data(storeSSL,
                (uint32_t)peer_certificate_data_index());
            decoded = SDMMD__decode_certificate(data);
            uint32_t data1 = i2d_X509(cert, NULL);
            uint32_t data2 = i2d_X509(decoded, NULL);
            if (data1 == data2)
            {
                uint32_t length1 = i2d_X509(cert, &var_16);
                uint32_t length2 = i2d_X509(decoded, &var_8);
                if (length1 == length2)
                {
                    if (memcmp(var_8, var_16, length1) == 0)
                    {
                        result = true;
                    }
                    else
                    {
                        result = false;
                    }
                }
                else
                {
                    result = false;
                }
            }
        }
        else
        {
            printf("%s: Error verifying cert: unable to compare.\n", __FUNCTION__);
            result = false;
        }
        Safe(free, var_8);
        Safe(free, var_16);
    }
    else
    {
        printf("%s: Error verifying cert: (%d %s).\n", __FUNCTION__, value,
            X509_verify_cert_error_string(X509_STORE_CTX_get_error(store)));
    }
    return result;
}

SSL *SDMMD_lockssl_handshake(uint64_t socket, CFTypeRef hostCert, CFTypeRef deviceCert,
    CFTypeRef hostPrivKey, uint32_t num)
{
    SSL *ssl = NULL;
    SSL_CTX *sslCTX = NULL;
    sdmmd_return_t result = kAMDSuccess;
    BIO_METHOD *bioMethod = BIO_s_socket();
    BIO *bioSocket = BIO_new(bioMethod);
    if (bioSocket)
    {
        BIO_set_fd(bioSocket, (int)socket, 0);
        X509 *cert = SDMMD__decode_certificate(hostCert);
        if (cert == NULL)
        {
            printf("_create_ssl_context: Could not certificate.\n");
        }
        RSA *rsa = NULL;
        BIO *dataBIO = SDMMD__create_bio_from_data(hostPrivKey);
        if (dataBIO == NULL)
        {
            printf("_create_ssl_context: Could not decode host private key.\n");
            Safe(X509_free, cert);
        }
        else
        {
            PEM_read_bio_RSAPrivateKey(dataBIO, &rsa, NULL, NULL);
            Safe(BIO_free, dataBIO);
            if (rsa)
            {
                if (hostCert)
                {
                    sslCTX = SSL_CTX_new(TLSv1_method());
                    if (sslCTX)
                    {
                        result = SSL_CTX_use_certificate(sslCTX, cert);
                        if (result == 0)
                        {
                            printf("_create_ssl_context: Could not set certificate.\n");
                        }
                        result = SSL_CTX_use_RSAPrivateKey(sslCTX, rsa);
                        if (result == 0)
                        {
                            printf("_create_ssl_context: Could not set private key.\n");
                        }
                    }
                    else
                    {
                        printf("_create_ssl_context: Could not create SSLv3 context.\n");
                    }
                }
                //Safe(RSA_free,rsa);
                //Safe(X509_free,cert);
                if (sslCTX)
                {
                    ssl = SSL_new(sslCTX);
                    if (ssl)
                    {
                        if (num)
                        {
                            SSL_set_connect_state(ssl);
                        }
                        else
                        {
                            SSL_set_accept_state(ssl);
                        }
                        SSL_set_verify(ssl, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT,
                            SDMMD__ssl_verify_callback);
                        SSL_set_verify_depth(ssl, 0);
                        SSL_set_bio(ssl, bioSocket, bioSocket);
                        SSL_set_ex_data(ssl,
                            (uint32_t)peer_certificate_data_index(),
                                (void *)deviceCert);

                        ERR_clear_error();
                        result = SSL_do_handshake(ssl);
                        if (result == 1)
                        {
                            SSL_CTX_free(sslCTX);
                        }
                        else
                        {
                            uint32_t err = SSL_get_error(ssl, result);
                            if (err)
                            {
                                char *reason = SDMMD_ssl_strerror(ssl, err);
                                printf("%s: SSL handshake fatal lower level error %d: %s.\n",
                                    __FUNCTION__, err, reason);
                            }
                            else
                            {
                                char *reason = SDMMD_ssl_strerror(ssl, 0);
                                printf("%s: SSL handshake controlled failure %d: %s.\n", __FUNCTION__,
                                    err, reason);
                            }
                            Safe(SSL_free, ssl);
                            ssl = NULL;
                        }
                    }
                    else
                    {
                        printf("_create_ssl: Could not create SSL thing.\n");
                    }
                }
            }
            else
            {
                printf("_create_ssl_context: Could not decode private key.\n");
                Safe(X509_free, cert);
            }
        }
    }
    else
    {
        printf("%s: Could not create SSL bio.\n", __FUNCTION__);
    }
    return ssl;
}

sdmmd_return_t SDMMD_lockconn_enable_ssl(SDMMD_lockdown_conn *lockdown_conn, CFTypeRef hostCert,
    CFTypeRef deviceCert, CFTypeRef hostPrivKey, uint32_t num)
{
    sdmmd_return_t result = kAMDSuccess;
    SSL *handshake = SDMMD_lockssl_handshake(lockdown_conn.connection, hostCert, deviceCert,
        hostPrivKey, num);
    if (handshake)
    {
        lockdown_conn.ssl = handshake;
    }
    else
    {
        result = kAMDErrorError;
    }
    return result;
}

sdmmd_return_t SDMMD_lockconn_disable_ssl(SDMMD_lockdown_conn *lockdown_conn)
{
    sdmmd_return_t result = kAMDSuccess;
    if (lockdown_conn.ssl)
    {
        result = SSL_shutdown(lockdown_conn.ssl);

        if (result == -1)
        {
            printf("%s: Could not shutdown SSL connection %d.\n", __FUNCTION__, -1);
        }
        SSL_free(lockdown_conn.ssl);
        lockdown_conn.ssl = NULL;
    }
    return result;
}

sdmmd_return_t SDMMD_lockconn_send_message(SDMMD_AMDevice* device, CFDictionaryRef dict)
{
    sdmmd_return_t result = kAMDSuccess;
    if (device.lockdown_conn)
    {
        if (dict)
        {
            bool useSSL = (device.lockdown_conn.ssl ? true : false);
            SocketConnection conn;
            if (useSSL)
            {
                conn = (SocketConnection){true, {.ssl = device.lockdown_conn.ssl}};
            }
            else
            {
                conn = (SocketConnection){false,
                    {.conn = (uint32_t)device.lockdown_conn.connection}};
            }

            SDMMD_ServiceSendMessage(conn, dict, kCFPropertyListXMLFormat_v1_0);
        }
        else
        {
            printf("%s: Could not encode message as XML.\n", __FUNCTION__);
        }
    }
    else
    {
        result = SDMMD_AMDeviceIsValid(device);
        if (result == false)
        {
            result = kAMDSendMessageError;
        }
    }
    return result;
}

sdmmd_return_t SDMMD_lockconn_receive_message(SDMMD_AMDevice* device, CFMutableDictionaryRef *dict)
{
    sdmmd_return_t result = kAMDSuccess;
    if (device.lockdown_conn)
    {
        bool useSSL = (device.lockdown_conn.ssl ? true : false);
        SocketConnection conn;
        if (useSSL)
        {
            conn = (SocketConnection){true, {.ssl = device.lockdown_conn.ssl}};
        }
        else
        {
            conn = (SocketConnection){false,
                {.conn = (uint32_t)device.lockdown_conn.connection}};
        }

        result = SDMMD_ServiceReceiveMessage(conn, (CFPropertyListRef *)dict);
    }
    else
    {
        result = SDMMD_AMDeviceIsValid(device);
        if (result == kAMDSuccess)
        {
            result = kAMDReadError;
        }
    }
    return result;
}

CFTypeRef SDMMD_copy_lockdown_value(SDMMD_AMDevice* device, CFStringRef domain, CFStringRef key,
    CFStringRef *err)
{
    CFTypeRef value = NULL;
    sdmmd_return_t result = kAMDSuccess;

    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.lockdown_conn == 0)
    {
        result = kAMDNotConnectedError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef request = SDMMD__CreateMessageDict(CFSTR("GetValue"));
    if (request == NULL)
    {
        result = kAMDNoResourcesError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef response = NULL;
    if (domain && CFStringCompare(domain, CFSTR("NULL"), 0) != 0)
    {
        CFDictionarySetValue(request, CFSTR("Domain"), domain);
    }

    if (key && CFStringCompare(key, CFSTR("NULL"), 0) != 0)
    {
        CFDictionarySetValue(request, CFSTR("Key"), key);
    }

    result = SDMMD_lockconn_send_message(device, request);
    CFSafeRelease(request);
    CheckErrorAndReturn(result);

    result = SDMMD_lockconn_receive_message(device, &response);
    CheckErrorAndReturn(result);
    if (response)
    {
        CFStringRef error = CFDictionaryGetValue(response, CFSTR("Error"));
        if (error)
        {
            if (CFGetTypeID(error) == CFStringGetTypeID())
            {
                if (err)
                {
                    // Retain error if it is being passed to caller
                    *err = CFRetain(error);
                }
                result = (sdmmd_return_t)SDMMD__ConvertLockdowndError(error);
            }
            else
            {
                result = kAMDInvalidResponseError;
            }
        }
        else
        {
            // Retain returned value from response
            value = CFRetain(CFDictionaryGetValue(response, CFSTR("Value")));
            result = kAMDSuccess;
        }
    }
    CFSafeRelease(response);

ExitLabel:
    if (!SDM_MD_CallSuccessful(result))
    {
        printf("%s: Could not copy value (%x)\n", __FUNCTION__, result);
    }
    return value;
}

sdmmd_return_t SDMMD_send_set_value(SDMMD_AMDevice* device, CFStringRef domain, CFStringRef key,
    CFTypeRef value)
{
    sdmmd_return_t result = kAMDSuccess;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.lockdown_conn == NULL)
    {
        result = kAMDNotConnectedError;
    }
    CheckErrorAndReturn(result);

    if (key == NULL || value == NULL)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef setVal = SDMMD__CreateMessageDict(CFSTR("SetValue"));
    if (setVal == NULL)
    {
        result = kAMDNoResourcesError;
    }
    CheckErrorAndReturn(result);

    if (domain)
    {
        CFDictionarySetValue(setVal, CFSTR("Domain"), domain);
    }
    CFDictionarySetValue(setVal, CFSTR("Key"), key);
    CFDictionarySetValue(setVal, CFSTR("Value"), value);
    result = SDMMD_lockconn_send_message(device, setVal);
    CFSafeRelease(setVal);
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef resultDict = NULL;
    result = SDMMD_lockconn_receive_message(device, &resultDict);
    if (result == kAMDSuccess)
    {
        result = SDMMD__ErrorHandler(SDMMD__ConvertLockdowndError, resultDict);
        CFSafeRelease(resultDict);
    }

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_lockdown_connection_destory(SDMMD_lockdown_conn *lockdownCon)
{
    sdmmd_return_t result = kAMDSuccess;
    if (lockdownCon)
    {
        Safe(SSL_free, lockdownCon.ssl);
        lockdownCon.ssl = NULL;
        if (lockdownCon.connection != -1)
        {
            result = close((uint32_t)lockdownCon.connection);
            if (result == -1)
            {
                printf("%s: close(2) on socket %lld failed: %d.\n", __FUNCTION__,
                       lockdownCon.connection, result);
            }
            lockdownCon.connection = 0;
        }
        Safe(free, lockdownCon.pointer);
        result = kAMDSuccess;

        lockdownCon = NULL;
    }
    return result;
}

sdmmd_return_t SDMMD_send_unpair(SDMMD_AMDevice* device, CFStringRef hostId)
{
    sdmmd_return_t result = kAMDSuccess;

    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.lockdown_conn == NULL)
    {
        result = kAMDNotConnectedError;
    }
    CheckErrorAndReturn(result);

    if (hostId == NULL)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef dict = SDMMD__CreateMessageDict(CFSTR("Unpair"));
    if (dict == NULL)
    {
        result = kAMDNoResourcesError;
    }
    CheckErrorAndReturn(result);

    const void *keys[1] = {CFSTR("HostID")};
    const void *values[1] = {hostId};
    CFDictionaryRef host = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    if (host)
    {
        CFDictionarySetValue(dict, CFSTR("PairRecord"), host);
        result = SDMMD_lockconn_send_message(device, dict);
        CFSafeRelease(host);
        if (SDM_MD_CallSuccessful(result))
        {
            CFMutableDictionaryRef response = NULL;
            result = SDMMD_lockconn_receive_message(device, &response);
            //PrintCFType(response);
            if (SDM_MD_CallSuccessful(result))
            {
                result = SDMMD__ErrorHandler(SDMMD__ConvertLockdowndError, response);
            }
        }
    }
    CFSafeRelease(dict);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_send_pair(SDMMD_AMDevice* device, CFMutableDictionaryRef pairRecord, CFTypeRef slip, CFTypeRef options,
    CFDataRef *escrowBag, CFDictionaryRef *extendedResponse)
{
    sdmmd_return_t result = kAMDSuccess;
    CFMutableDictionaryRef response = NULL;

    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.lockdown_conn == NULL)
    {
        result = kAMDNotConnectedError;
    }
    CheckErrorAndReturn(result);

    if (pairRecord == NULL)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (escrowBag == NULL)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef pRecord = SDMMD__CreateMessageDict(CFSTR("Pair"));
    if (pRecord == NULL)
    {
        result = kAMDNoResourcesError;
    }
    CheckErrorAndReturn(result);

    CFDictionarySetValue(pRecord, CFSTR("PairRecord"), pairRecord);
    if (slip)
    {
        CFDictionarySetValue(pRecord, CFSTR("PermissionSlip"), slip);
    }

    if (options)
    {
        CFDictionarySetValue(pRecord, CFSTR("PairingOptions"), options);
    }
    result = SDMMD_lockconn_send_message(device, pRecord);
    CFSafeRelease(pRecord);
    CheckErrorAndReturn(result);

    result = SDMMD_lockconn_receive_message(device, &response);
    CheckErrorAndReturn(result);

    result = SDMMD__ErrorHandler(SDMMD__ConvertLockdowndError, response);

    if (SDM_MD_CallSuccessful(result))
    {
        // Return EscrowBag value
        CFDataRef bagData = CFDictionaryGetValue(response, CFSTR("EscrowBag"));

        if (bagData)
        {
            if (escrowBag)
            {
                *escrowBag = CFRetain(bagData);
            }
        }
        else
        {
            result = kAMDInvalidResponseError;
        }
    }

    if (CFDictionaryContainsKey(response, CFSTR("ExtendedResponse")))
    {
        // Return ExtendedResponse
        CFDictionaryRef extendedResponseDict = CFDictionaryGetValue(response, CFSTR("ExtendedResponse"));

        if (extendedResponseDict)
        {
            if (extendedResponse)
            {
                *extendedResponse = CFRetain(extendedResponseDict);
            }
        }
    }

    CFSafeRelease(response);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_send_validate_pair(SDMMD_AMDevice* device, CFStringRef hostId)
{
    sdmmd_return_t result = kAMDSuccess;

    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.lockdown_conn == NULL)
    {
        result = kAMDNotConnectedError;
    }
    CheckErrorAndReturn(result);

    if (hostId == NULL)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef dict = SDMMD__CreateMessageDict(CFSTR("ValidatePair"));
    if (dict == NULL)
    {
        result = kAMDNoResourcesError;
    }
    CheckErrorAndReturn(result);

    const void *keys[1] = {CFSTR("HostID")};
    const void *values[1] = {hostId};
    CFDictionaryRef host = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);
    if (host)
    {
        CFDictionarySetValue(dict, CFSTR("PairRecord"), host);
        result = SDMMD_lockconn_send_message(device, dict);
        CFSafeRelease(host);
        if (SDM_MD_CallSuccessful(result))
        {
            CFMutableDictionaryRef response = NULL;
            result = SDMMD_lockconn_receive_message(device, &response);
            //PrintCFType(response);
            if (SDM_MD_CallSuccessful(result))
            {
                result = SDMMD__ErrorHandler(SDMMD__ConvertLockdowndError, response);
            }
            CFSafeRelease(response);
        }
    }
    CFSafeRelease(dict);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_copy_daemon_name(SDMMD_AMDevice* device, CFStringRef *name)
{
    sdmmd_return_t result = kAMDSuccess;
    CFMutableDictionaryRef response = NULL;

    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.lockdown_conn == NULL)
    {
        result = kAMDNotConnectedError;
    }
    CheckErrorAndReturn(result);

    if (name == NULL)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef queryDict = SDMMD__CreateMessageDict(CFSTR("QueryType"));
    if (queryDict == NULL)
    {
        result = kAMDNoResourcesError;
    }
    CheckErrorAndReturn(result);

    result = SDMMD_lockconn_send_message(device, queryDict);
    CFSafeRelease(queryDict);
    CheckErrorAndReturn(result);

    result = SDMMD_lockconn_receive_message(device, &response);
    CheckErrorAndReturn(result);
    if (response && CFDictionaryGetCount(response))
    {
        CFTypeRef val = CFDictionaryGetValue(response, CFSTR("Error"));
        if (val == NULL)
        {
            val = CFDictionaryGetValue(response, CFSTR("Type"));
            if (val)
            {
                if (CFGetTypeID(val) == CFStringGetTypeID())
                {
                    CFRetain(val);
                    *name = val;
                }
            }
            else
            {
                result = kAMDInvalidResponseError;
            }
        }
    }
    CFSafeRelease(response);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD__CopyEscrowBag(SDMMD_AMDevice* device, CFDataRef *bag)
{
    sdmmd_return_t result = kAMDInvalidArgumentError;
    if (device)
    {
        CFMutableDictionaryRef dict = NULL;
        result = SDMMD__CreatePairingRecordFromRecordOnDiskForIdentifier(device, &dict);
        if (result == kAMDSuccess)
        {
            CFTypeRef wifiValue = NULL;
            if (!CFDictionaryContainsKey(dict, CFSTR("WiFiMACAddress")))
            {
                wifiValue = SDMMD_AMDeviceCopyValue(device, CFSTR("NULL"), CFSTR("WiFiMACAddress"));
                if (wifiValue != NULL && CFGetTypeID(wifiValue) == CFStringGetTypeID())
                {
                    CFDictionarySetValue(dict, CFSTR("WiFiMACAddress"), wifiValue);
                }
            }
            CFSafeRelease(wifiValue);

            CFTypeRef bagValue = CFDictionaryGetValue(dict, CFSTR("EscrowBag"));
            if (bagValue)
            {
                if (CFGetTypeID(bagValue) == CFDataGetTypeID())
                {
                    CFRetain(bagValue);
                    *bag = bagValue;
                    char *path = calloc(1024, sizeof(char));
                    SDMMD__PairingRecordPathForIdentifier((__bridge CFStringRef)(device.unique_device_id), path);
                    result = SDMMD_store_dict(dict, path, true);
                    if (result)
                    {
                        printf("%s: Failed to store escrow bag to %s.\n", __FUNCTION__, path);
                    }
                    Safe(free, path);
                }
            }
        }
        CFSafeRelease(dict);
    }
    return result;
}

bool SDMMD_isDeviceAttachedUSB(uint32_t location_id)
{
    bool foundDevice = false;
    io_iterator_t iterator;
    mach_port_t masterPort;
    kern_return_t kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kr == kIOReturnSuccess && masterPort)
    {
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator);
        io_service_t usbDevice;
        while ((usbDevice = IOIteratorNext(iterator)))
        {
            CFTypeRef supportsIPhoneOS = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("SupportsIPhoneOS"),
                kCFAllocatorDefault, kIORegistryIterateRecursively);
            if (supportsIPhoneOS)
            {
                CFTypeRef locationId = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("locationID"),
                    kCFAllocatorDefault, kIORegistryIterateRecursively);
                if (locationId)
                {
                    uint32_t loc_id;
                    CFNumberGetValue(locationId, kCFNumberSInt32Type, &loc_id);
                    foundDevice = (loc_id == location_id);
                    CFSafeRelease(locationId);
                }
                CFSafeRelease(supportsIPhoneOS);
            }
            Safe(IOObjectRelease, usbDevice);
            if (foundDevice)
            {
                break;
            }
        }
    }
    else
    {
        printf("Error: Couldn't create a master I/O Kit port(%08x)\n", kr);
    }
    mach_port_deallocate(mach_task_self(), masterPort);
    return foundDevice;
}

bool SDMMD_isDeviceAttached(uint32_t device_id)
{
    bool result = false;

    NSArray *devices = [SDMMD_USBMuxListener sharedInstance].deviceList;

    if (devices)
    {
        for (uint32_t i = 0; i < devices.count; i++)
        {
            SDMMD_AMDevice* device = (SDMMD_AMDevice*)[devices objectAtIndex:i];
            if (device)
            {
                uint32_t fetched_id = SDMMD_AMDeviceGetConnectionID(device);
                result = (fetched_id == device_id); // ? SDMMD_isDeviceAttachedUSB(device.location_id) : false);
                if (result)
                {
                    break;
                }
            }
        }
    }

    return result;
}

sdmmd_return_t SDMMD_send_activation(SDMMD_AMDevice* device, CFDictionaryRef dict)
{
    sdmmd_return_t result = kAMDInvalidArgumentError;
    CFMutableDictionaryRef message = NULL;
    if (device)
    {
        result = kAMDNotConnectedError;
        if (device.device_active)
        {
            result = kAMDInvalidArgumentError;
            if (dict)
            {
                result = kAMDNoResourcesError;
                CFMutableDictionaryRef messageDict = SDMMD__CreateMessageDict(CFSTR("Activate"));
                if (messageDict)
                {
                    CFDictionarySetValue(messageDict, CFSTR("ActivationRecord"), dict);
                    result = SDMMD_lockconn_send_message(device, messageDict);
                    if (result == kAMDSuccess)
                    {
                        result = SDMMD_lockconn_receive_message(device, &message);
                        if (result == kAMDSuccess)
                        {
                            CFTypeRef msg = CFDictionaryGetValue(message, CFSTR("Error"));
                            if (msg)
                            {
                                result = kAMDInvalidResponseError;
                                if (CFGetTypeID(msg) == CFStringGetTypeID())
                                {
                                    result = (sdmmd_return_t)SDMMD__ConvertLockdowndError(msg);
                                }
                            }
                        }
                    }
                }
                CFSafeRelease(messageDict);
            }
        }
    }
    CFSafeRelease(message);
    return result;
}

sdmmd_return_t SDMMD_send_deactivation(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDInvalidArgumentError;
    CFMutableDictionaryRef message = NULL;
    if (device)
    {
        result = kAMDNotConnectedError;
        if (device.device_active)
        {
            //result = kAMDInvalidArgumentError;
            CFMutableDictionaryRef messageDict = SDMMD__CreateMessageDict(CFSTR("Deactivate"));
            if (messageDict)
            {
                result = SDMMD_lockconn_send_message(device, messageDict);
                if (result == kAMDSuccess)
                {
                    result = SDMMD_lockconn_receive_message(device, &message);
                    if (result == kAMDSuccess)
                    {
                        CFTypeRef msg = CFDictionaryGetValue(message, CFSTR("Error"));
                        if (msg)
                        {
                            result = kAMDInvalidResponseError;
                            if (CFGetTypeID(msg) == CFStringGetTypeID())
                            {
                                result = (sdmmd_return_t)SDMMD__ConvertLockdowndError(msg);
                            }
                        }
                    }
                }
            }
            else
            {
                result = kAMDNoResourcesError;
            }
            CFSafeRelease(messageDict);
        }
    }
    CFSafeRelease(message);
    return result;
}

sdmmd_return_t SDMMD_send_session_start(SDMMD_AMDevice* device, CFDictionaryRef record, CFStringRef *session)
{
    sdmmd_return_t result = kAMDInvalidArgumentError;
    CFTypeRef var32 = NULL;
    bool isValidHostBUID = false;
    CFMutableDictionaryRef message = NULL;
    if (device)
    {
        CFTypeRef var20 = NULL;
        result = kAMDNotConnectedError;
        if (device.lockdown_conn)
        {
            result = kAMDInvalidArgumentError;
            if (record && session)
            {
                message = SDMMD__CreateMessageDict(CFSTR("StartSession"));
                result = kAMDNoResourcesError;
                if (message)
                {
                    CFTypeRef hostId = CFDictionaryGetValue(record, CFSTR("HostID"));
                    CFDictionarySetValue(message, CFSTR("HostID"), hostId);
                    CFTypeRef bonjourId = CFDictionaryGetValue(record, CFSTR("SystemBUID"));
                    if (bonjourId)
                    {
                        CFTypeRef systemBUID = SDMMD_AMDCopySystemBonjourUniqueID();
                        isValidHostBUID = (CFStringCompare(bonjourId, systemBUID, 0) == kCFCompareEqualTo);
                        //CFDictionarySetValue(message, CFSTR("HostID"), bonjourId);
                        result = kAMDSuccess;
                        CFSafeRelease(systemBUID);
                    }
                }
            }
            if (isValidHostBUID && result == kAMDSuccess)
            {
                // SDM: this is a check against the host BUID and the BUID of the pairing record. this is a security measure.
                result = SDMMD_lockconn_send_message(device, message);
                //PrintCFType(message);
                if (result == kAMDSuccess)
                {
                    CFMutableDictionaryRef recvDict = NULL;
                    result = SDMMD_lockconn_receive_message(device, &recvDict);
                    //PrintCFType(recvDict);
                    if (result == kAMDSuccess)
                    {
                        //CFShow(recvDict);
                        CFTypeRef resultStr = CFDictionaryGetValue(recvDict, CFSTR("Error"));
                        if (!resultStr)
                        {
                            CFTypeRef sessionId = CFDictionaryGetValue(recvDict, CFSTR("SessionID"));
                            result = kAMDMissingSessionIDError;
                            if (sessionId)
                            {
                                CFRetain(sessionId);
                                CFTypeID typeId = CFGetTypeID(sessionId);
                                result = kAMDMissingSessionIDError;
                                if (typeId == CFStringGetTypeID())
                                {
                                    CFTypeRef hostCert = CFDictionaryGetValue(record, CFSTR("HostCertificate"));
                                    CFTypeRef hostPriKey = CFDictionaryGetValue(record, CFSTR("HostPrivateKey"));
                                    CFTypeRef deviceCert = CFDictionaryGetValue(record, CFSTR("DeviceCertificate"));
                                    result = SDMMD_lockconn_enable_ssl(device.lockdown_conn, hostCert, deviceCert,
                                        hostPriKey, 1);
                                    if (result != 0)
                                    {
                                        bool isValid = SDMMD_AMDeviceIsValid(device);
                                        result = kAMDDeviceDisconnectedError;
                                        if (isValid)
                                        {
                                            SDMMD_AMDeviceDisconnect(device);
                                            SDMMD_AMDeviceConnect(device);
                                            result = kAMDInvalidResponseError;
                                        }
                                    }
                                    else
                                    {
                                        CFRetain(sessionId);
                                        *session = sessionId;
                                    }
                                }
                                CFSafeRelease(sessionId);
                            }
                        }
                        else
                        {
                            result = kAMDInvalidResponseError;
                            if (CFGetTypeID(resultStr) == CFStringGetTypeID())
                            {
                                result = (sdmmd_return_t)SDMMD__ConvertLockdowndError(resultStr);
                            }
                        }
                    }
                    CFSafeRelease(recvDict);
                }
            }
            else
            {
                printf("%s: Mismatch between Host SystemBUID and Pairing Record SystemBUID, recreate pairing record to ensure host is trustworthy.\n", __FUNCTION__);
                result = kAMDInvalidHostIDError;
            }
            CFSafeRelease(message);
        }
        CFSafeRelease(var32);
        CFSafeRelease(var20);
    }
    return result;
}

sdmmd_return_t SDMMD_send_session_stop(SDMMD_AMDevice* device, CFTypeRef session)
{
    sdmmd_return_t result = kAMDSuccess;
    CFMutableDictionaryRef response = NULL;

    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.lockdown_conn == NULL)
    {
        result = kAMDNotConnectedError;
    }
    CheckErrorAndReturn(result);

    if (!session)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    CFMutableDictionaryRef dict = SDMMD__CreateMessageDict(CFSTR("StopSession"));
    if (!dict)
    {
        result = kAMDNoResourcesError;
    }
    CheckErrorAndReturn(result);

    CFDictionarySetValue(dict, CFSTR("SessionID"), session);
    result = SDMMD_lockconn_send_message(device, dict);
    CFSafeRelease(dict);
    CheckErrorAndReturn(result);

    result = SDMMD_lockconn_receive_message(device, &response);
    CheckErrorAndReturn(result);

    CFTypeRef error = CFDictionaryGetValue(response, CFSTR("Error"));
    if (error && CFGetTypeID(error) == CFStringGetTypeID())
    {
        result = (sdmmd_return_t)SDMMD__ConvertLockdowndError(error);
    }
    else
    {
        SDMMD_lockconn_disable_ssl(device.lockdown_conn);
        result = kAMDSuccess;
    }
    CFSafeRelease(response);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_AMDeviceStartSession(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    CFMutableDictionaryRef record = NULL;
    CFDataRef key = NULL;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.device_active == 0)
    {
        result = kAMDDeviceDisconnectedError;
    }
    CheckErrorAndReturn(result);

    SDMMD__mutex_lock(device.mutex_lock);
    result = SDMMD__CreatePairingRecordFromRecordOnDiskForIdentifier(device, &record);
    CheckErrorAndReturn(result);

    CFStringRef session = NULL;
    result = SDMMD_send_session_start(device, record, &session);
    device.session = CFBridgingRelease(session);
    if (result == kAMDSuccess && device.session)
    {
        Boolean hasKey = CFDictionaryContainsKey(record, CFSTR("EscrowBag"));
        if (!hasKey)
        {
            hasKey = CFDictionaryContainsKey(record, CFSTR("WiFiMACAddress"));
        }
        if (hasKey)
        {
            SDMMD__CopyEscrowBag(device, &key);
        }
    }
    else
    {
        char *reason = SDMMD_AMDErrorString(result);
        printf("%s: Could not start session with device %u: %s\n", __FUNCTION__, device.device_id, reason);
    }
    SDMMD__mutex_unlock(device.mutex_lock);
    CFSafeRelease(record);
    CFSafeRelease(key);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_AMDeviceStopSession(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.device_active == 0)
    {
        result = kAMDDeviceDisconnectedError;
    }
    CheckErrorAndReturn(result);

    SDMMD__mutex_lock(device.mutex_lock);
    result = kAMDSessionInactiveError;
    if (device.session != 0)
    {
        result = SDMMD_send_session_stop(device, (__bridge CFTypeRef)(device.session));
        if (result)
        {
            char *reason = SDMMD_AMDErrorString(result);
            printf("%s: Could not stop session with device %u: %s\n", __FUNCTION__, device.device_id, reason);
        }
        device.session = nil;
    }
    SDMMD__mutex_unlock(device.mutex_lock);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_AMDeviceActivate(SDMMD_AMDevice* device, CFDictionaryRef options)
{
    sdmmd_return_t result = kAMDSuccess;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.device_active == 0)
    {
        result = kAMDDeviceDisconnectedError;
    }
    CheckErrorAndReturn(result);

    SDMMD__mutex_lock(device.mutex_lock);
    result = SDMMD_send_activation(device, options);
    if (result != 0)
    {
        char *reason = SDMMD_AMDErrorString(result);
        printf("%s: Could not activate device %u %s.\n", __FUNCTION__, device.device_id, reason);
    }
    SDMMD__mutex_unlock(device.mutex_lock);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_AMDeviceDeactivate(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    if (device)
    {
        if (device.device_active)
        {
            SDMMD__mutex_lock(device.mutex_lock);
            result = SDMMD_send_deactivation(device);
            if (result != 0)
            {
                char *reason = SDMMD_AMDErrorString(result);
                printf("%s: Could not deactivate device %u: %s\n", __FUNCTION__, device.device_id, reason);
            }
            SDMMD__mutex_unlock(device.mutex_lock);
        }
        else
        {
            result = kAMDDeviceDisconnectedError;
        }
    }
    else
    {
        result = kAMDInvalidArgumentError;
    }
    return result;
}

sdmmd_return_t SDMMD__connect_to_port(SDMMD_AMDevice* device, uint32_t port, bool hasTimeout, uint32_t *socketConn, bool isSSL)
{
    sdmmd_return_t result = kAMDInvalidArgumentError;
    port = htons(port);
    uint32_t sock = -1;
    uint32_t mask = 1;
    struct timeval timeout = {.tv_sec = 25, .tv_usec = 0};
    if (device != NULL && socketConn)
    {
        result = kAMDDeviceDisconnectedError;
        if (device.device_active)
        {
            if (device.connection_type == kAMDeviceConnectionTypeWiFi)
            {
                size_t dataLen = device.network_address.length;
                struct sockaddr_storage address = {0};
                if (dataLen == sizeof(struct sockaddr_storage))
                {
                    [device.network_address getBytes:&address length:dataLen];

                    socklen_t socketaddrSize = address.ss_len;
                    if (address.ss_family != AF_INET && address.ss_family != AF_INET6)
                    {
                        printf("%s: This doesn't seem to be a valid AF_INET or AF_INET6\n", __FUNCTION__);
                        return result;
                    }

                    struct sockaddr_in *portChange = (struct sockaddr_in *)&address;
                    portChange->sin_port = (in_port_t)port;

                    sock = socket(address.ss_family, SOCK_STREAM, 0);

                    setsockoptCond(sock, SOL_SOCKET, SO_NOSIGPIPE, mask, {});

                    result = connect(sock, (const struct sockaddr *)&address, socketaddrSize);
                    if (result != 0)
                    {
                        result = kAMDMuxConnectError;
                        return result;
                    }

                    setsockoptCond(sock, SOL_SOCKET, SO_NOSIGPIPE, mask, {});
                    setsockoptCond(sock, SOL_SOCKET, SO_SNDTIMEO, timeout, {});
                    setsockoptCond(sock, SOL_SOCKET, SO_RCVTIMEO, timeout, {});
                }
                else
                {
                    printf("%s: doesn't look like a sockaddr_storage.\n", __FUNCTION__);
                    result = kAMDMuxConnectError;
                }
            }
            else
            {
                result = SDMMD_USBMuxConnectByPort(device, port, &sock);
                if (result)
                {
                    result = kAMDMuxConnectError;
                }
            }
            *socketConn = sock;
        }
        if (sock == -1)
        {
            if (close(sock) == -1)
            {
                printf("%s: close(2) on socket %d failed: %d.\n", __FUNCTION__, sock, errno);
            }
        }
    }
    return result;
}

sdmmd_return_t SDMMD_AMDeviceConnect(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    uint32_t socket = -1;
    uint32_t lockdownPort = 62078;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    //result = SDMMD_AMDevicePair(device);
    if (SDM_MD_CallSuccessful(result))
    {
        result = kAMDDeviceDisconnectedError;
        if (device.device_active /*&& device.connection_type == kAMDeviceConnectionTypeUSB*/)
        {
            SDMMD__mutex_lock(device.mutex_lock);
            if (device.lockdown_conn == 0)
            {
                uint32_t status = SDMMD__connect_to_port(device, lockdownPort, true, &socket, false);
                if (status == kAMDSuccess)
                {
                    result = kAMDNotConnectedError;
                    if (socket != -1)
                    {
                        device.lockdown_conn = SDMMD_lockdown_connection_create(socket);
                        result = kAMDNoResourcesError;
                        if (device.lockdown_conn.connection)
                        {
                            CFStringRef daemon = NULL;
                            status = SDMMD_copy_daemon_name(device, &daemon);
                            if (daemon && status == 0)
                            {
                                //result = kAMDInvalidResponseError;
                                if (CFStringCompare(daemon, CFSTR(AMSVC_LOCKDOWN), 0) != kCFCompareEqualTo)
                                {
                                    char *dname = SDMCFStringGetString(daemon);
                                    printf("%s: This is not the droid you're looking for (is actually %s). move along,  move along.\n", __FUNCTION__, dname);
                                    Safe(free, dname);
                                    SDMMD_AMDeviceDisconnect(device);
                                    result = kAMDWrongDroidError;
                                }
                                else
                                {
                                    result = kAMDSuccess;
                                }
                                CFSafeRelease(daemon);
                            }
                            else
                            {
                                result = kAMDNoResourcesError;
                            }
                        }
                    }
                }
                else
                {
                    printf("%s: Could not connect to lockdown port (%d) on device %d - %s: 0x%x\n", __FUNCTION__,
                        lockdownPort, device.device_id, "device with no name", result);
                }
            }
            else
            {
                bool valid = SDMMD_AMDeviceIsValid(device);
                if (!valid)
                {
                    SDMMD_AMDeviceDisconnect(device);
                    result = kAMDDeviceDisconnectedError;
                }
            }
            SDMMD__mutex_unlock(device.mutex_lock);
        }
    }
    else
    {
        if (result == kAMDPairingProhibitedError)
        {
            printf("%s: Could not pair with device, please accept trust prompt on device.\n", __FUNCTION__);
        }
    }
    /*if (socket != 0xff) {
     if (close(socket) == 0xff) {
     uint32_t errorNum = errno;
     printf("SDMMD_AMDeviceConnect: close(2) on socket %d socket, failed: %d.\n",socket, errorNum);
     }
     }*/
    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_AMDeviceDisconnect(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    if (device)
    {
        SDMMD__mutex_lock(device.mutex_lock);
        result = SDMMD_lockdown_connection_destory(device.lockdown_conn);
        device.lockdown_conn = NULL;
        device.session = nil;
        SDMMD__mutex_unlock(device.mutex_lock);
    }
    else
    {
        result = kAMDInvalidArgumentError;
    }
    return result;
}

bool SDMMD_AMDeviceIsValid(SDMMD_AMDevice* device)
{
    bool result = false;
    if (device && device.device_active != 0)
    {
        bool attached = SDMMD_isDeviceAttached(device.device_id);
        if (!attached)
        {
            device.device_active = 0;
        }
        else
        {
            result = true;
        }
    }
    return result;
}

sdmmd_return_t SDMMD_AMDeviceValidatePairing(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.device_active == 0)
    {
        result = kAMDDeviceDisconnectedError;
    }
    CheckErrorAndReturn(result);

    char *recordPath = calloc(1, sizeof(char[1025]));
    SDMMD__PairingRecordPathForIdentifier((__bridge CFStringRef)(device.unique_device_id), recordPath);
    CFMutableDictionaryRef dict = SDMMD__CreateDictFromFileContents(recordPath);
    if (!dict)
    {
        result = kAMDMissingPairRecordError;
    }
    Safe(free, recordPath);
    CheckErrorAndReturn(result);

    CFStringRef host = CFDictionaryGetValue(dict, CFSTR("HostID"));
    if (!host)
    {
        result = kAMDInvalidPairRecordError;
    }
    else
    {
        CFRetain(host);
    }
    CFSafeRelease(dict);
    CheckErrorAndReturn(result);

    SDMMD__mutex_lock(device.mutex_lock);
    result = SDMMD_send_validate_pair(device, host);
    if (result)
    {
        printf("%s: Could not validate pairing with device %u: %s\n", __FUNCTION__,
            device.device_id, SDMMD_AMDErrorString(result));
    }
    SDMMD__mutex_unlock(device.mutex_lock);
    CFSafeRelease(host);

    ExitLabelAndReturn(result);
}

sdmmd_return_t SDMMD_AMDeviceUnpair(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.device_active == 0)
    {
        result = kAMDDeviceDisconnectedError;
    }
    CheckErrorAndReturn(result);

    char *recordPath = calloc(1, sizeof(char[1025]));
    SDMMD__PairingRecordPathForIdentifier((__bridge CFStringRef)(device.unique_device_id), recordPath);
    CFMutableDictionaryRef dict = SDMMD__CreateDictFromFileContents(recordPath);
    if (!dict)
    {
        result = kAMDMissingPairRecordError;
        Safe(free, recordPath);
    }
    CheckErrorAndReturn(result);

    CFStringRef host = CFDictionaryGetValue(dict, CFSTR("HostID"));
    if (!host)
    {
        result = kAMDInvalidPairRecordError;
        Safe(free, recordPath);
    }
    else
    {
        CFRetain(host);
    }
    CFSafeRelease(dict);
    CheckErrorAndReturn(result);

    SDMMD__mutex_lock(device.mutex_lock);
    // SDM: remove pair record file
    remove(recordPath);
    result = SDMMD_send_unpair(device, host);
    if (result)
    {
        printf("%s: Could not unpair device %u: %s\n", __FUNCTION__, device.device_id, SDMMD_AMDErrorString(result));
    }
    SDMMD__mutex_unlock(device.mutex_lock);
    CFSafeRelease(host);
    Safe(free, recordPath);

    ExitLabelAndReturn(result);
}

bool SDMMD_AMDeviceIsPaired(SDMMD_AMDevice* device)
{
    bool result = false;

    if (device)
    {
        SDMMD__mutex_lock(device.mutex_lock);
        char *path = calloc(1, sizeof(char[1025]));

        SDMMD__PairingRecordPathForIdentifier((__bridge CFStringRef)(device.unique_device_id), path);
        SDMMD__mutex_unlock(device.mutex_lock);
        struct stat buffer;
        int statResult = stat(path, &buffer);
        if (statResult)
        {
            uint32_t errorNum = errno;
            if (errorNum != 2)
            {
                errorNum = errno;
                char *errStr = strerror(errorNum);
                printf("%s: Could not stat %s: %s\n", __FUNCTION__, path, errStr);
            }
        }
        else
        {
            result = true;
        }
        Safe(free, path);
    }
    else
    {
        printf("%s: No device.\n", __FUNCTION__);
    }

    return result;
}

sdmmd_return_t SDMMD_AMDevicePair(SDMMD_AMDevice* device)
{
    sdmmd_return_t result = kAMDSuccess;
    if (!SDMMD_AMDeviceIsPaired(device))
    {
        result = SDMMD_AMDevicePairWithOptions(device, NULL);
    }
    return result;
}

sdmmd_return_t SDMMD_AMDevicePairWithOptions(SDMMD_AMDevice* device, CFDictionaryRef options)
{
    return SDMMD_AMDeviceExtendedPairWithOptions(device, options, NULL);
}

sdmmd_return_t SDMMD_AMDeviceExtendedPairWithOptions(SDMMD_AMDevice* device, CFDictionaryRef options,
    CFDictionaryRef *extendedResponse)
{
    sdmmd_return_t result = kAMDInvalidArgumentError;
    bool getValue = true;
    CFMutableDictionaryRef chapCopy = NULL;

    if (device)
    {
        if (device.device_active)
        {
            SDMMD__mutex_lock(device.mutex_lock);

            if (options)
            {
                // Extract the ChaperoneCertificate dictionary from options, if present
                // It will be sent separately in the pair message
                CFDictionaryRef chapCert = CFDictionaryGetValue(options, CFSTR("ChaperoneCertificate"));
                if (chapCert)
                {
                    if (CFPropertyListIsValid(chapCert, kCFPropertyListXMLFormat_v1_0) ||
                        CFPropertyListIsValid(chapCert, kCFPropertyListBinaryFormat_v1_0))
                    {
                        CFIndex chapKeyCount = CFDictionaryGetCount(chapCert);
                        if (chapKeyCount != 1)
                        {
                            chapCopy = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, chapCert);
                            CFDictionaryRemoveValue(chapCopy, CFSTR("ChaperoneCertificate"));
                        }
                    }
                    else
                    {
                        // Clear flag so error is returned (invalid argument)
                        getValue = false;
                    }
                }
            }

            if (getValue)
            {
                result = kAMDPairingProhibitedError;

                // Retrieve device info for generating pairing record
                CFTypeRef wifiAddress = SDMMD_copy_lockdown_value(device, NULL, CFSTR(kWiFiAddress), NULL);
                CFTypeRef devicePubKey = SDMMD_copy_lockdown_value(device, NULL, CFSTR(kDevicePublicKey), NULL);

                if (devicePubKey && CFGetTypeID(devicePubKey) == CFDataGetTypeID())
                {
                    // Generate pairing record to send to device and store
                    CFMutableDictionaryRef record = SDMMD__CreatePairingMaterial(devicePubKey);
                    if (record)
                    {
                        CFTypeRef buid = SDMMD_AMDCopySystemBonjourUniqueID();
                        if (buid)
                        {
                            CFDictionarySetValue(record, CFSTR("SystemBUID"), buid);

                            // Create a copy of pairing record to modify and send to device
                            CFMutableDictionaryRef sendPair = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, record);
                            if (sendPair)
                            {
                                // Remove nonessential fields
                                CFDictionaryRemoveValue(sendPair, CFSTR("RootPrivateKey"));
                                CFDictionaryRemoveValue(sendPair, CFSTR("HostPrivateKey"));

                                CFDataRef escrowBag = NULL;
                                // Send pairing record and options to device
                                // escrowBag is returned by reference with +1 retain
                                result = SDMMD_send_pair(device, sendPair, chapCopy, options, &escrowBag, extendedResponse);
                                if (result == kAMDSuccess && escrowBag != NULL)
                                {
                                    // Store escrow bag from device
                                    CFDictionarySetValue(record, CFSTR("EscrowBag"), escrowBag);

                                    if (wifiAddress && CFGetTypeID(wifiAddress) == CFStringGetTypeID())
                                    {
                                        CFDictionarySetValue(record, CFSTR("WiFiMACAddress"), wifiAddress);
                                    }

                                    // Save pairing record dict to disk
                                    char *path = calloc(1, sizeof(char[1025]));
                                    SDMMD__PairingRecordPathForIdentifier((__bridge CFStringRef)(device.unique_device_id), path);
                                    result = SDMMD_store_dict(record, path, true);
                                    if (result)
                                    {
                                        printf("%s: Could not store pairing record at '%s'.\n", __FUNCTION__, path);
                                        result = kAMDPermissionError;
                                    }
                                    else
                                    {
                                        result = kAMDSuccess;
                                    }
                                    free(path);
                                }
                                else
                                {
                                    printf("%s: Could not pair with the device %u: 0x%x\n", __FUNCTION__,
                                        device.device_id, result);
                                }
                                CFSafeRelease(escrowBag);
                            }
                            else
                            {
                                result = kAMDNoResourcesError;
                            }
                            CFSafeRelease(sendPair);
                        }
                        else
                        {
                            printf("%s: Could not create system BUID.\n", __FUNCTION__);
                        }
                        CFSafeRelease(buid);
                    }
                    else
                    {
                        printf("%s: Could not create pairing material.\n", __FUNCTION__);
                    }
                    CFSafeRelease(record);
                }
                else
                {
                    result = kAMDInvalidResponseError;
                }
                CFSafeRelease(devicePubKey);
                CFSafeRelease(wifiAddress);
                CFSafeRelease(chapCopy);
            }

            SDMMD__mutex_unlock(device.mutex_lock);
        }
        else
        {
            result = kAMDDeviceDisconnectedError;
        }
    }

    return result;
}

CFStringRef SDMMD_AMDeviceCopyUDID(SDMMD_AMDevice* device)
{
    CFStringRef udid = CFSTR("");
    if (device)
    {
        udid = (__bridge CFStringRef)(device.unique_device_id);
    }
    return CFStringCreateCopy(kCFAllocatorDefault, udid);
}

uint32_t SDMMD_AMDeviceUSBDeviceID(SDMMD_AMDevice* device)
{
    uint32_t result = 0;
    if (device)
    {
        SDMMD__mutex_lock(device.mutex_lock);
        result = device.device_id;
        SDMMD__mutex_unlock(device.mutex_lock);
    }
    return result;
}

uint32_t SDMMD_AMDeviceUSBLocationID(SDMMD_AMDevice* device)
{
    uint32_t result = 0;
    if (device)
    {
        SDMMD__mutex_lock(device.mutex_lock);
        result = device.location_id;
        SDMMD__mutex_unlock(device.mutex_lock);
    }
    else
    {
        printf("%s: No device\n", __FUNCTION__);
    }
    return result;
}

uint16_t SDMMD_AMDeviceUSBProductID(SDMMD_AMDevice* device)
{
    uint16_t result = 0;
    if (device)
    {
        SDMMD__mutex_lock(device.mutex_lock);
        result = device.product_id & 0xffff;
        SDMMD__mutex_unlock(device.mutex_lock);
    }
    else
    {
        printf("%s: No device\n", __FUNCTION__);
    }
    return result;
}

uint32_t SDMMD_AMDeviceGetConnectionID(SDMMD_AMDevice* device)
{
    return SDMMD_AMDeviceUSBDeviceID(device);
}

CFTypeRef SDMMD_AMDeviceCopyValue(SDMMD_AMDevice* device, CFStringRef domain, CFStringRef key)
{
    CFTypeRef value = NULL;
    if (device.device_active)
    {
        SDMMD__mutex_lock(device.mutex_lock);
        CFStringRef err = NULL;
        value = SDMMD_copy_lockdown_value(device, domain, key, &err);
        if (err)
        {
            CFSafeRelease(value);
            value = NULL;
        }
        CFSafeRelease(err);
        SDMMD__mutex_unlock(device.mutex_lock);
    }
    return value;
}

sdmmd_return_t SDMMD_AMDeviceSetValue(SDMMD_AMDevice* device, CFStringRef domain, CFStringRef key, CFTypeRef value)
{
    sdmmd_return_t result = kAMDSuccess;
    if (!device)
    {
        result = kAMDInvalidArgumentError;
    }
    CheckErrorAndReturn(result);

    if (device.device_active == 0)
    {
        result = kAMDDeviceDisconnectedError;
    }
    CheckErrorAndReturn(result);

    SDMMD__mutex_lock(device.mutex_lock);
    result = SDMMD_send_set_value(device, domain, key, value);
    if (result != kAMDSuccess)
    {
        printf("%s: Could not set value\n", __FUNCTION__);
    }
    SDMMD__mutex_unlock(device.mutex_lock);

    ExitLabelAndReturn(result);
}

SDMMD_AMDevice* SDMMD_AMDeviceCreateFromProperties(NSDictionary *dictionary)
{
    SDMMD_AMDevice* device = NULL;
    if (dictionary)
    {
        device = [[SDMMD_AMDevice alloc] init];
        if (device)
        {
            NSDictionary *properties =
                ([[dictionary allKeys] containsObject:@"Properties"] ?
                    [dictionary objectForKey:@"Properties"] : dictionary);

            device.device_id = [(NSNumber *)properties[@"DeviceID"] intValue];

            device.unique_device_id = properties[@"SerialNumber"];

            NSString *linkType = properties[@"ConnectionType"];

            if ([linkType isEqualToString:@"USB"])
            {
                device.connection_type = kAMDeviceConnectionTypeUSB;

                device.product_id = [(NSNumber *)properties[@"ProductID"] intValue];

                device.location_id = [(NSNumber *)properties[@"LocationID"] intValue];
            }
            else if ([linkType isEqualToString:@"Network"] || [linkType isEqualToString:@"WiFi"])
            {
                device.connection_type = kAMDeviceConnectionTypeWiFi;
                device.network_address = properties[@"NetworkAddress"];

                NSMutableString *serviceName = [NSMutableString stringWithString:properties[@"EscapedFullServiceName"]];
                [serviceName replaceOccurrencesOfString:@"\\" withString:@"" options:NSCaseInsensitiveSearch range:
                    NSMakeRange(0, serviceName.length)];

                device.service_name = serviceName;

                device.interface_index = [(NSNumber *)properties[@"InterfaceIndex"] intValue];
            }

            device.device_active = YES;

            device.device_active = true;

            sdmmd_mutex_init(device.mutex_lock);
        }
    }
    return device;
}

bool SDMMD_AMDeviceIsAttached(SDMMD_AMDevice* device)
{
    bool result = false;
    USBMuxPacket *devicesPacket = [[USBMuxPacket alloc] initWithType:kSDMMD_USBMuxPacketListDevicesType payload:nil];
    [[SDMMD_USBMuxListener sharedInstance] send:&devicesPacket];
    for (uint32_t i = 0; i < [SDMMD_USBMuxListener sharedInstance].deviceList.count; i++)
    {
        SDMMD_AMDevice* deviceCheck = (SDMMD_AMDevice*)[[SDMMD_USBMuxListener sharedInstance].deviceList objectAtIndex:i];
        if (SDMMD_AMDeviceGetConnectionID(device) == SDMMD_AMDeviceGetConnectionID(deviceCheck))
        {
            result = true;
            break;
        }
    }
    return result;
}

sdmmd_sim_return_t SDMMD_GetSIMStatusCode(SDMMD_AMDevice* device)
{
    sdmmd_sim_return_t result = KnownSIMCodes[0];
    CFStringRef deviceSIMStatus = SDMMD_AMDeviceCopyValue(device, NULL, CFSTR(kSIMStatus));
    if (deviceSIMStatus)
    {
        for (uint32_t i = 1; i < kKnownSIMCodesNum; i++)
        {
            if (CFStringCompare(deviceSIMStatus, KnownSIMCodes[i].codeName, 0) == kCFCompareEqualTo)
            {
                result = KnownSIMCodes[i];
                break;
            }
        }
    }
    CFSafeRelease(deviceSIMStatus);
    return result;
}

sdmmd_activation_return_t SDMMD_GetActivationStatus(SDMMD_AMDevice* device)
{
    sdmmd_activation_return_t result = KnownActivationStates[0];
    CFStringRef deviceActivationState = SDMMD_AMDeviceCopyValue(device, NULL, CFSTR(kActivationState));
    if (deviceActivationState)
    {
        for (uint32_t i = 1; i < kKnownActivationStatesNum; i++)
        {
            if (CFStringCompare(deviceActivationState, KnownActivationStates[i].statusName, 0) == kCFCompareEqualTo)
            {
                result = KnownActivationStates[i];
                break;
            }
        }
    }
    CFSafeRelease(deviceActivationState);
    return result;
}

sdmmd_interface_return_t SDMMD_AMDeviceGetInterfaceType(SDMMD_AMDevice* device)
{
    sdmmd_interface_return_t result = kAMDInterfaceConnectionTypeInvalid;
    if (device)
    {
        SDMMD__mutex_lock(device.mutex_lock);

        if (device.connection_type == kAMDeviceConnectionTypeUSB)
        {
            result = kAMDInterfaceConnectionTypeDirect;
        }
        else if (device.connection_type == kAMDeviceConnectionTypeWiFi)
        {
            result = kAMDInterfaceConnectionTypeIndirect;
        }

        SDMMD__mutex_unlock(device.mutex_lock);
    }
    else
    {
        printf("%s: No device\n", __FUNCTION__);
    }
    return result;
}

#endif
