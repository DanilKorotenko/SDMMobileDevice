//
//  USBMuxPacket.m
//  SDMMobileDevice
//
//  Created by Danil Korotenko on 7/2/24.
//

#import "USBMuxPacket.h"

static uint32_t transactionId = 0;

struct USBMuxPacketBody
{
    uint32_t length;
    uint32_t reserved;
    uint32_t type;
    uint32_t tag;
};


@interface USBMuxPacket ()

@end

@implementation USBMuxPacket

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.payload = [NSDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithType:(SDMMD_USBMuxPacketMessageType)type payload:(NSDictionary * _Nullable)dict
{
    self = [self init];
    if (self)
    {
        if (type == kSDMMD_USBMuxPacketListenType || type == kSDMMD_USBMuxPacketConnectType)
        {
            self.timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 30);
        }
        else
        {
            self.timeout = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5);
        }

        self.bodyLength = 16;
        self.bodyReserved = 1;
        self.bodyType = 8;
        self.bodyTag = transactionId;

        transactionId++;

        NSMutableDictionary *mutablePayload =[NSMutableDictionary dictionary];

        mutablePayload[@"BundleID"] = @"com.samdmarshall.sdmmobiledevice";
        mutablePayload[@"ClientVersionString"] = @"usbmuxd-323";
        mutablePayload[@"ProgName"] = @"SDMMobileDevice";

        uint32_t version = 3;
        mutablePayload[@"kLibUSBMuxVersion"] = @(version);

        if (dict)
        {
            [mutablePayload addEntriesFromDictionary:dict];
        }

        mutablePayload[@"MessageType"] = SDMMD_USBMuxPacketMessage(type);

        if (type == kSDMMD_USBMuxPacketConnectType)
        {
            uint16_t port = 0x7ef2;
            mutablePayload[@"PortNumber"] = @(port);
        }

        if (type == kSDMMD_USBMuxPacketListenType)
        {
            uint32_t connection = 0;
            mutablePayload[@"ConnType"] = @(connection);
        }

        self.payload = [NSDictionary dictionaryWithDictionary:mutablePayload];
        NSError *error = nil;
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:self.payload format:NSPropertyListXMLFormat_v1_0 options:0
            error:&error];

        self.bodyLength = 16 + (uint32_t)xmlData.length;
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
        USBMuxPacket *otherPacket = (USBMuxPacket *)other;
        return self.bodyTag == otherPacket.bodyTag;
    }
}

- (NSUInteger)hash
{
    return self.bodyTag;
}

- (uint32_t)bodySize
{
    return sizeof(struct USBMuxPacketBody);
}

- (void)setBodyWithPtr:(void *)aPtr
{
    struct USBMuxPacketBody *body = (struct USBMuxPacketBody *)aPtr;
    self.bodyLength = body->length;
    self.bodyType = body->type;
    self.bodyTag = body->tag;
    self.bodyReserved = body->reserved;
}

- (NSData *)bodyData
{
    struct USBMuxPacketBody body;
    body.length =   self.bodyLength;
    body.type =     self.bodyType;
    body.tag =      self.bodyTag;
    body.reserved = self.bodyReserved;

    NSData *result = [NSData dataWithBytes:&body length:sizeof(struct USBMuxPacketBody)];
    return result;
}

@end
