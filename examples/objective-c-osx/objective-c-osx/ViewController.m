//
//  ViewController.m
//  objective-c-osx
//
//  Created by Simon Maynard on 7/24/15.
//  Copyright (c) 2015 Bugsnag. All rights reserved.
//

#import "ViewController.h"
#import "CxxException.h"
#import <Bugsnag/Bugsnag.h>

@implementation ViewController

- (IBAction)rethrownExceptionClick:(id)sender {
    @try {
        @throw [NSException exceptionWithName:@"rethrownException" reason:@"reason" userInfo:nil];
    }
    @catch (NSException *exception) {
        @throw exception;
    }
}

- (IBAction)caughtExceptionNotifyClick:(id)sender {
    @try {
        @throw [NSException exceptionWithName:@"caughtExceptionNotify" reason:@"reason" userInfo:nil];
    }
    @catch (NSException *exception) {
        [Bugsnag notify:exception];
    }
}

- (IBAction)uncaughtExceptionClick:(id)sender {
    @throw [NSException exceptionWithName:@"uncaughtException" reason:@"reason" userInfo:nil];
}

- (IBAction)generateNSError:(id)sender {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:@"//invalid/path/somewhere" error:&error];
    if (error) {
        [Bugsnag notifyError:error];
    }
}

- (IBAction)generateSignal:(id)sender {
    __builtin_trap();
}

- (IBAction)generateMachException:(id)sender {
    void (*ptr)(void) = NULL;
    ptr();
}

- (IBAction)generateCxxException:(id)sender {
    [[CxxException new] crash];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
