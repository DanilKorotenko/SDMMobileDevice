//
//  main.m
//  HelloSDMMobileDevice
//
//  Created by Danil Korotenko on 6/27/24.
//

#import <Foundation/Foundation.h>
#import <SDMMobileDevice/SDMMobileDevice.h>

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        NSLog(@"Hello, World!");

        InitializeSDMMobileDevice();

        dispatch_main();
    }
    return 0;
}
