//
//  DeviceRequest.m
//  SDMMobileDevice
//
//  Created by Danil Korotenko on 7/15/24.
//

#import "DeviceMessage.h"

@interface DeviceMessage ()

@property (readonly) NSMutableDictionary *mutableDictionary;

@end

@implementation DeviceMessage

@synthesize mutableDictionary;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        mutableDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithRequest:(NSString *)aType
{
    self = [self init];
    if (self)
    {
        mutableDictionary[@"Request"] = aType;
    }
    return self;
}

- (instancetype)initMessageWithRequest:(NSString *)aType
{
    self = [self initWithRequest:aType];
    if (self)
    {
        mutableDictionary[@"ProtocolVersion"] = @"2";
        mutableDictionary[@"Label"] = [[[[NSProcessInfo processInfo] arguments] objectAtIndex:0] lastPathComponent];
    }
    return self;
}

#pragma mark -

- (BOOL)displayPass
{
    return [(NSNumber *)mutableDictionary[@"DisplayPass"] boolValue];
}

- (void)setDisplayPass:(BOOL)displayPass
{
    mutableDictionary[@"DisplayPass"] = @(displayPass);
}

- (BOOL)waitForDisconnect
{
    return [(NSNumber *)mutableDictionary[@"WaitForDisconnect"] boolValue];
}

- (void)setWaitForDisconnect:(BOOL)waitForDisconnect
{
    mutableDictionary[@"WaitForDisconnect"] = @(waitForDisconnect);
}

#pragma mark -

- (NSDictionary *)dictionary
{
    return mutableDictionary;
}

@end
