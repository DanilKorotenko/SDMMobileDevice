//
//  DeviceRequest.m
//  SDMMobileDevice
//
//  Created by Danil Korotenko on 7/15/24.
//

#import "DeviceMessage.h"

@interface DeviceMessage ()

@property (readonly) NSMutableDictionary *dictionary;

@end

@implementation DeviceMessage

@synthesize dictionary;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithRequest:(NSString *)aType
{
    self = [self init];
    if (self)
    {
        dictionary[@"Request"] = aType;
    }
    return self;
}

- (instancetype)initMessageWithRequest:(NSString *)aType
{
    self = [self initWithRequest:aType];
    if (self)
    {
        dictionary[@"ProtocolVersion"] = @"2";
        dictionary[@"Label"] = [[[[NSProcessInfo processInfo] arguments] objectAtIndex:0] lastPathComponent];
    }
    return self;
}

#pragma mark -

- (BOOL)displayPass
{
    return [(NSNumber *)self.dictionary[@"DisplayPass"] boolValue];
}

- (void)setDisplayPass:(BOOL)displayPass
{
    self.dictionary[@"DisplayPass"] = @(displayPass);
}

- (BOOL)waitForDisconnect
{
    return [(NSNumber *)self.dictionary[@"WaitForDisconnect"] boolValue];
}

- (void)setWaitForDisconnect:(BOOL)waitForDisconnect
{
    self.dictionary[@"WaitForDisconnect"] = @(waitForDisconnect);
}

- (NSString *)service
{
    return self.dictionary[@"Service"];
}

- (void)setService:(NSString *)service
{
    self.dictionary[@"Service"] = service;
}

- (NSData *)escrowBag
{
    return self.dictionary[@"EscrowBag"];
}

- (void)setEscrowBag:(NSData *)escrowBag
{
    self.dictionary[@"EscrowBag"] = escrowBag;
}

#pragma mark -

- (NSData *)xmlData
{
    NSError *error = nil;
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:self.dictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    return xmlData;
}

@end
