//
//  USBMuxResponseCode.m
//  SDMMobileDevice
//
//  Created by Danil Korotenko on 7/1/24.
//

#import "USBMuxResponseCode.h"
#import "SDMMD_USBMuxListener_Types.h"

@interface USBMuxResponseCode ()

@property(readwrite) NSUInteger code;
@property(strong) NSString *string;


@end

@implementation USBMuxResponseCode

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    if (self)
    {
        NSNumber *resultCode = nil;
        if ([[dict allKeys] containsObject:@"Number"])
        {
            resultCode = [dict objectForKey:@"Number"];
        }

        if ([[dict allKeys] containsObject:@"String"])
        {
            self.string = [dict objectForKey:@"String"];
        }

        if (resultCode)
        {
            self.code = resultCode.integerValue;
            switch (self.code)
        {
            case SDMMD_USBMuxResult_OK:
            {
                self.string = @"OK";
                break;
            }
            case SDMMD_USBMuxResult_BadCommand:
            {
                self.string = @"Bad Command";
                break;
            }
            case SDMMD_USBMuxResult_BadDevice:
            {
                self.string = @"Bad Device";
                break;
            }
            case SDMMD_USBMuxResult_ConnectionRefused:
            {
                self.string = @"Connection Refused by Device";
                break;
            }
            case SDMMD_USBMuxResult_Unknown0:
            {
                break;
            }
            case SDMMD_USBMuxResult_BadMessage:
            {
                self.string = @"Incorrect Message Contents";
                break;
            }
            case SDMMD_USBMuxResult_BadVersion:
            {
                self.string = @"Bad Protocol Version";
                break;
            }
            case SDMMD_USBMuxResult_Unknown2:
            {
                break;
            }
            default:
            {
                break;
            }
        }
    }

    }
    return self;
}

@end
