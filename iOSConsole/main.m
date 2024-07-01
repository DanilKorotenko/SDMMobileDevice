//
//  main.c
//  iOSConsole
//
//  Created by Samantha Marshall on 1/1/14.
//  Copyright (c) 2014 Samantha Marshall. All rights reserved.
//

#include <getopt.h>
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>

#include "SDMMobileDevice.h"
#include "Core.h"

#include "Features.h"

static char *helpArg = "-h";
static char *listArg = "-l,--list";
static char *deviceArg = "-d,--device";
static char *attachArg = "-s,--attach";
static char *queryArg = "-q,--query";
static char *appsArg = "-a,--apps";
static char *infoArg = "-i,--info";
static char *runArg = "-r,--run";
static char *powerArg = "-p,--diag";
static char *devArg = "-x,--develop";
static char *installArg = "-t,--install";
static char *profileArg = "-c,--profile";
ATR_UNUSED static char *testArg = "-z,--test";

enum iOSConsoleOptions
{
    OptionsHelp = 0x0,
    OptionsList,
    OptionsDevice,
    OptionsAttach,
    OptionsQuery,
    OptionsApps,
    OptionsInfo,
    OptionsRun,
    OptionsDiag,
    OptionsDev,
    OptionsInstall,
    OptionsConfig,
    OptionsTest,
    OptionsCount
};

static struct option long_options[OptionsCount] =
{
    {"help", optional_argument, 0x0, 'h'},
    {"list", no_argument, 0x0, 'l'},
    {"device", required_argument, 0x0, 'd'},
    {"attach", required_argument, 0x0, 's'},
    {"query", required_argument, 0x0, 'q'},
    {"apps", no_argument, 0x0, 'a'},
    {"info", no_argument, 0x0, 'i'},
    {"run", required_argument, 0x0, 'r'},
    {"diag", required_argument, 0x0, 'p'},
    {"develop", no_argument, 0x0, 'x'},
    {"install", required_argument, 0x0, 't'},
    {"profile", required_argument, 0x0, 'c'},
    {"test", no_argument, 0x0, 'z'}};

static bool optionsEnable[OptionsCount] = {};

int main(int argc, const char *argv[])
{
    SDMMobileDevice;

    NSString *udid = nil;
    NSString *service = nil;
    NSString *help = nil;

    NSString *domain = nil;
    NSString *key = nil;

    NSString *bundle = nil;

    NSString *diagArg = nil;

    bool searchArgs = true;

    NSString *installPath = nil;

    int c;
    while (searchArgs)
    {
        int option_index = 0x0;
        c = getopt_long(argc, (char *const *)argv, "lh:d:ais:q:r:p:t:c:z", long_options,
            &option_index);
        if (c == -1)
        {
            break;
        }
        switch (c)
        {
            case 'h':
            {
                if (optarg)
                {
                    help = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                }
                optionsEnable[OptionsHelp] = true;
                searchArgs = false;
                break;
            };
            case 'l':
            {
                optionsEnable[OptionsList] = true;
                searchArgs = false;
                break;
            };
            case 'd':
            {
                if (optarg && !optionsEnable[OptionsDevice])
                {
                    optionsEnable[OptionsDevice] = true;
                    udid = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                }
                break;
            }
            case 's':
            {
                if (optarg && !optionsEnable[OptionsAttach])
                {
                    service = [NSString stringWithCString:optarg
                        encoding:NSUTF8StringEncoding];
                    optionsEnable[OptionsAttach] = true;
                }
                else
                {
                    printf("please specify a service name to attach");
                }
                break;
            };
            case 'q':
            {
                if (optarg && !optionsEnable[OptionsQuery])
                {
                    NSString *argValue = [NSString stringWithCString:optarg
                        encoding:NSUTF8StringEncoding];
                    NSArray *argsArray = [argValue componentsSeparatedByString:@"="];
                    if (argsArray.count >= 1)
                    {
                        domain = [argsArray objectAtIndex:0];
                        if ([domain isEqualToString:@"all"])
                        {
                            domain = [NSString stringWithCString:kAllDomains
                                encoding:NSUTF8StringEncoding];
                        }
                        optionsEnable[OptionsQuery] = true;
                    }
                    if (argsArray.count == 2)
                    {
                        key = [argsArray objectAtIndex:1];
                    }
                    else
                    {
                        key = [NSString stringWithCString:kAllKeys encoding:NSUTF8StringEncoding];
                    }
                }
                break;
            };
            case 'a':
            {
                optionsEnable[OptionsApps] = true;
                break;
            };
            case 'i':
            {
                optionsEnable[OptionsInfo] = true;
                break;
            };
            case 'r':
            {
                if (optarg && !optionsEnable[OptionsRun])
                {
                    bundle = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                    optionsEnable[OptionsRun] = true;
                }
                break;
            };
            case 'p':
            {
                if (optarg && !optionsEnable[OptionsDiag])
                {
                    diagArg = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                    optionsEnable[OptionsDiag] = true;
                }
                break;
            };
            case 'x':
            {
                optionsEnable[OptionsDev] = true;
                break;
            }
            case 't':
            {
                if (optarg)
                {
                    optionsEnable[OptionsInstall] = true;
                    installPath = [NSString stringWithCString:optarg
                        encoding:NSUTF8StringEncoding];
                }
                break;
            }
            case 'c':
            {
                if (optarg)
                {
                    optionsEnable[OptionsConfig] = true;
                    installPath = [NSString stringWithCString:optarg
                        encoding:NSUTF8StringEncoding];
                }
                break;
            }
            case 'z':
            {
                optionsEnable[OptionsTest] = true;
                break;
            }
            default:
            {
                printf("--help for help");
                break;
            };
        }
    }
    if (optionsEnable[OptionsHelp])
    {
        if (!help)
        {
            printf("%s [service|query] : list available services or queries\n", helpArg);
            printf("%s : list attached devices\n", listArg);
            printf("%s [UDID] : specify a device\n", deviceArg);
            printf("%s [service] : attach to [service]\n", attachArg);
            printf("%s <domain>=<key> : query value for <key> in <domain>, specify 'null' for global domain\n", queryArg);
            printf("%s : display installed apps\n", appsArg);
            printf("%s : display info of a device\n", infoArg);
            printf("%s [bundle id] : run an application with specified [bundle id]\n", runArg);
            printf("%s [sleep|reboot|shutdown] : perform diag power operations on a device\n", powerArg);
            printf("%s : setup device for development\n", devArg);
            printf("%s [.app path] : install specificed .app to a device\n", installArg);
            printf("%s [.mobileconfig path] : install specificed .mobileconfig to a device\n", profileArg);
        }
        else
        {
            if ([help isEqualToString:@"service"])
            {
                printf(" shorthand : service identifier\n--------------------------------\n");
                for (uint32_t i = 0x0; i < SDM_MD_Service_Count; i++)
                {
                    printf("%10s : %s\n", SDMMDServiceIdentifiers[i].shorthand,
                        SDMMDServiceIdentifiers[i].identifier);
                }
            }

            if ([help isEqualToString:@"query"])
            {
                for (uint32_t i = 0x0; i < SDM_MD_Domain_Count; i++)
                {
                    printf("Domain: %s\n", SDMMDKnownDomain[i].domain);
                    for (uint32_t j = 0x0; j < SDMMDKnownDomain[i].keyCount; j++)
                    {
                        printf("\t%s\n", SDMMDKnownDomain[i].keys[j]);
                    }
                    printf("\n\n");
                }
            }
        }
    }

    if (optionsEnable[OptionsList])
    {
        ListConnectedDevices();
    }

    if (optionsEnable[OptionsDevice])
    {
        if (optionsEnable[OptionsInfo])
        {
        }
        else if (optionsEnable[OptionsApps])
        {
            LookupAppsOnDevice([udid UTF8String]);
        }
        else if (optionsEnable[OptionsAttach])
        {
            PerformService([udid UTF8String], [service UTF8String]);
        }
        else if (optionsEnable[OptionsQuery])
        {
            PerformQuery([udid UTF8String], [domain UTF8String], [key UTF8String]);
        }
        else if (optionsEnable[OptionsRun])
        {
            RunAppOnDeviceWithIdentifier([udid UTF8String], [bundle UTF8String], false);
        }
        else if (optionsEnable[OptionsDiag])
        {
            if (diagArg)
            {
                if ([diagArg isEqualToString:@"sleep"])
                {
                    SendSleepToDevice([udid UTF8String]);
                }
                else if ([diagArg isEqualToString:@"reboot"])
                {
                    SendRebootToDevice([udid UTF8String]);
                }
                else if ([diagArg isEqualToString:@"shutdown"])
                {
                    SendShutdownToDevice([udid UTF8String]);
                }
            }
        }
        else if (optionsEnable[OptionsDev])
        {
            SetupDeviceForDevelopment([udid UTF8String]);
        }
        else if (optionsEnable[OptionsInstall])
        {
            InstallAppToDevice([udid UTF8String], [installPath UTF8String]);
        }
        else if (optionsEnable[OptionsConfig])
        {
            InstallProfileToDevice([udid UTF8String], [installPath UTF8String]);
        }
        else if (optionsEnable[OptionsTest])
        {
            WhatDoesThisDo([udid UTF8String]);
        }
    }

    return 0;
}
