//
//  UsbMuxPacketConnect.m
//  SDM_MD_Tests
//
//  Created by Danil Korotenko on 7/5/24.
//

#import "UsbMuxPacketConnect.h"

@implementation UsbMuxPacketConnect

@synthesize payload;

- (instancetype)initWithDeviceId:(NSInteger)aDeviceId portNumber:(NSInteger)aPortNumber
{
    self = [super init];
    if (self)
    {
        NSMutableDictionary *mutablePayload =[NSMutableDictionary dictionaryWithDictionary:[self payload]];
        mutablePayload[@"DeviceID"] = @(aDeviceId);
        mutablePayload[@"PortNumber"] = @(aPortNumber);
        payload = [NSDictionary dictionaryWithDictionary:mutablePayload];
    }
    return self;
}

- (dispatch_time_t)timeout
{
    return dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 30);
}

- (NSString *)packetMessage
{
    return @"Connect";
}

- (NSDictionary *)payload
{
    if (payload == nil)
    {
        NSMutableDictionary *mutablePayload =[NSMutableDictionary dictionaryWithDictionary:[super payload]];
        mutablePayload[@"PortNumber"] = @(0x7ef2);
        payload = [NSDictionary dictionaryWithDictionary:mutablePayload];
    }
    return payload;
}

@end
