//
//  UsbMuxPacketListen.m
//  SDM_MD_Tests
//
//  Created by Danil Korotenko on 7/5/24.
//

#import "UsbMuxPacketListen.h"

@implementation UsbMuxPacketListen

@synthesize payload;

- (dispatch_time_t)timeout
{
    return dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 30);
}

- (NSString *)packetMessage
{
    return @"Listen";
}

- (NSDictionary *)payload
{
    if (payload == nil)
    {
        NSMutableDictionary *mutablePayload =[NSMutableDictionary dictionaryWithDictionary:[super payload]];
        mutablePayload[@"ConnType"] = @(0);
        payload = [NSDictionary dictionaryWithDictionary:mutablePayload];
    }
    return payload;
}

@end
