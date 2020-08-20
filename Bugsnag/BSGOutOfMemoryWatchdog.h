#import <Foundation/Foundation.h>

#define PLATFORM_WORD_SIZE sizeof(void*)*8

@class BugsnagConfiguration;

@interface BSGOutOfMemoryWatchdog : NSObject

@property(nonatomic, strong, readonly, nullable) NSDictionary *lastBootCachedFileInfo;

/**
 * Create a new watchdog using the sentinel path to store app/device state
 */
- (instancetype _Nullable)initWithSentinelPath:(NSString * _Nullable)sentinelFilePath
                       configuration:(BugsnagConfiguration * _Nullable)config
    NS_DESIGNATED_INITIALIZER;

/**
 * @return YES if the app was killed to end the previous app launch
 */
- (BOOL)didOOMLastLaunch;

/**
 * Begin monitoring for lifecycle events and report the OOM from the last launch (if any)
 */
- (void)enable;

/**
 * Stop monitoring for lifecycle events
 */
- (void)disable;

@end
