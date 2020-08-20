#import "BugsnagPlatformConditional.h"

#if BSG_PLATFORM_IOS || BSG_PLATFORM_TVOS
#define BSGOOMAvailable 1
#else
#define BSGOOMAvailable 0
#endif

#if BSGOOMAvailable
#import <UIKit/UIKit.h>
#endif
#import "BSGOutOfMemoryWatchdog.h"
#import "BSG_KSSystemInfo.h"
#import "BugsnagLogger.h"
#import "Bugsnag.h"
#import "BugsnagSessionTracker.h"
#import "Private.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagCollections.h"

@interface BSGOutOfMemoryWatchdog ()
@property(nonatomic, getter=isWatching) BOOL watching;
@property(nonatomic, strong) NSString *sentinelFilePath;
@property(nonatomic, getter=didOOMLastLaunch) BOOL oomLastLaunch;
@property(nonatomic, strong, readwrite) NSMutableDictionary *cachedFileInfo;
@property(nonatomic, strong, readwrite) NSDictionary *lastBootCachedFileInfo;
@property(nonatomic) NSString *codeBundleId;
@property(nonatomic) BugsnagConfiguration *config;
@end

@implementation BSGOutOfMemoryWatchdog

- (instancetype)init {
    self = [self initWithSentinelPath:nil configuration:nil];
    return self;
}

- (instancetype)initWithSentinelPath:(NSString *)sentinelFilePath
                       configuration:(BugsnagConfiguration *)config {
    if (sentinelFilePath.length == 0) {
        return nil; // disallow enabling a watcher without a file path
    }
    if (self = [super init]) {
        _sentinelFilePath = sentinelFilePath;
        _config = config;
#ifdef BSGOOMAvailable
        _oomLastLaunch = [self computeDidOOMLastLaunch];
        _cachedFileInfo = [self generateCacheInfo];
#endif
    }
    return self;
}

- (void)enable {
#if BSGOOMAvailable
    if ([self isWatching]) {
        return;
    }
    [self writeSentinelFile];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(disable:)
                   name:UIApplicationWillTerminateNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleTransitionToBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleTransitionToForeground:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleTransitionToActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleTransitionToInactive:)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleLowMemoryChange:)
                   name:UIApplicationDidReceiveMemoryWarningNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleUpdateSession:)
                   name:BSGSessionUpdateNotification
                 object:nil];
    [self.config addObserver:self
                  forKeyPath:NSStringFromSelector(@selector(releaseStage))
                     options:NSKeyValueObservingOptionNew
                     context:nil];
    self.watching = YES;
#endif
}

- (void)disable:(NSNotification *)note {
    [self disable];
}

- (void)disable {
    if (![self isWatching]) {
        // Avoid unsubscribing from KVO when not observing
        // From the docs:
        // > Asking to be removed as an observer if not already registered as
        // > one results in an NSRangeException. You either call
        // > `removeObserver:forKeyPath:context: exactly once for the
        // > corresponding call to `addObserver:forKeyPath:options:context:`
        return;
    }
    self.watching = NO;
    [self deleteSentinelFile];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    @try {
        [self.config removeObserver:self
                         forKeyPath:NSStringFromSelector(@selector(releaseStage))];
    } @catch (NSException *exception) {
        // Shouldn't happen, but if for some reason, unregistration happens
        // without registration, catch the resulting exception.
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *, id> *)change
                       context:(void *)context {
    id newValue = change[NSKeyValueChangeNewKey];
    BSGDictSetSafeObject(self.cachedFileInfo[@"app"], newValue, @"releaseStage");
    [self writeSentinelFile];
}

- (void)handleTransitionToActive:(NSNotification *)note {
    BSGDictSetSafeObject(self.cachedFileInfo[@"app"], @YES, @"isActive");
    [self writeSentinelFile];
}

- (void)handleTransitionToInactive:(NSNotification *)note {
    BSGDictSetSafeObject(self.cachedFileInfo[@"app"], @NO, @"isActive");
    [self writeSentinelFile];
}

- (void)handleTransitionToForeground:(NSNotification *)note {
    BSGDictSetSafeObject(self.cachedFileInfo[@"app"], @YES, @"inForeground");
    [self writeSentinelFile];
}

- (void)handleTransitionToBackground:(NSNotification *)note {
    BSGDictSetSafeObject(self.cachedFileInfo[@"app"], @NO, @"inForeground");
    [self writeSentinelFile];
}

- (void)handleLowMemoryChange:(NSNotification *)note {
    NSString *lowMemory = [BSG_RFC3339DateTool stringFromDate:[NSDate date]];
    BSGDictSetSafeObject(self.cachedFileInfo[@"device"], lowMemory, @"lowMemory");
    [self writeSentinelFile];
}

- (void)handleUpdateSession:(NSNotification *)note {
    id session = [note object];
    NSMutableDictionary *cache = (id)self.cachedFileInfo;
    if (session) {
        BSGDictSetSafeObject(cache, session, @"session");
    } else {
        [cache removeObjectForKey:@"session"];
    }
    [self writeSentinelFile];
}

- (void)setCodeBundleId:(NSString *)codeBundleId {
    _codeBundleId = codeBundleId;
    BSGDictInsertIfNotNil(self.cachedFileInfo[@"app"], codeBundleId, @"codeBundleId");

    if ([self isWatching]) {
        [self writeSentinelFile];
    }
}


- (BOOL)computeDidOOMLastLaunch {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.sentinelFilePath]) {
        NSDictionary *lastBootInfo = [self readSentinelFile];
        if (lastBootInfo != nil) {
            self.lastBootCachedFileInfo = lastBootInfo;
            NSString *lastBootBundleVersion =
                [lastBootInfo valueForKeyPath:@"app.bundleVersion"];
            NSString *lastBootAppVersion =
                [lastBootInfo valueForKeyPath:@"app.version"];
            NSString *lastBootOSVersion =
                [lastBootInfo valueForKeyPath:@"device.osBuild"];
            BOOL lastBootInForeground =
                [[lastBootInfo valueForKeyPath:@"app.inForeground"] boolValue];
            BOOL lastBootWasActive =
                [[lastBootInfo valueForKeyPath:@"app.isActive"] boolValue];
            NSString *osVersion = [BSG_KSSystemInfo osBuildVersion];
            NSDictionary *appInfo = [[NSBundle mainBundle] infoDictionary];
            NSString *bundleVersion =
                [appInfo valueForKey:@BSG_KSSystemField_BundleVersion];
            NSString *appVersion =
                [appInfo valueForKey:@BSG_KSSystemField_BundleShortVersion];
            BOOL sameVersions = [lastBootOSVersion isEqualToString:osVersion] &&
                                [lastBootBundleVersion isEqualToString:bundleVersion] &&
                                [lastBootAppVersion isEqualToString:appVersion];
            BOOL shouldReport = (lastBootInForeground && lastBootWasActive);
            [self deleteSentinelFile];
            return sameVersions && shouldReport;
        }
    }
    return NO;
}

- (void)deleteSentinelFile {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.sentinelFilePath
                                               error:&error];
    if (error) {
        bsg_log_err(@"Failed to delete oom watchdog file: %@", error);
        unlink([self.sentinelFilePath UTF8String]);
    }
}

- (NSDictionary *)readSentinelFile {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.sentinelFilePath options:0 error:&error];
    if (error) {
        bsg_log_err(@"Failed to read oom watchdog file: %@", error);
        return nil;
    }
    NSDictionary *contents = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        bsg_log_err(@"Failed to read oom watchdog file: %@", error);
        return nil;
    }
    return contents;
}


- (void)writeSentinelFile {
    NSError *error = nil;
    if (![NSJSONSerialization isValidJSONObject:self.cachedFileInfo]) {
        bsg_log_err(@"Cached oom watchdog data cannot be written as JSON");
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.cachedFileInfo options:0 error:&error];
    if (error) {
        bsg_log_err(@"Cached oom watchdog data cannot be written as JSON: %@", error);
        return;
    }
    [data writeToFile:self.sentinelFilePath atomically:YES];
}

- (NSMutableDictionary *)generateCacheInfo {
    NSDictionary *systemInfo = [BSG_KSSystemInfo systemInfo];
    NSMutableDictionary *cache = [NSMutableDictionary new];
    NSMutableDictionary *app = [NSMutableDictionary new];

    BSGDictSetSafeObject(app, systemInfo[@BSG_KSSystemField_BundleID], @"id");
    BSGDictSetSafeObject(app, systemInfo[@BSG_KSSystemField_BundleName], @"name");
    BSGDictSetSafeObject(app, self.config.releaseStage, @"releaseStage");
    BSGDictSetSafeObject(app, systemInfo[@BSG_KSSystemField_BundleShortVersion], @"version");
    BSGDictSetSafeObject(app, systemInfo[@BSG_KSSystemField_BundleVersion], @"bundleVersion");

    // 'codeBundleId' only (optionally) exists for React Native clients and defaults otherwise to nil
    BSGDictSetSafeObject(app, self.codeBundleId, @"codeBundleId");

#if BSGOOMAvailable
    UIApplicationState state = [BSG_KSSystemInfo currentAppState];
    BSGDictSetSafeObject(app, @([BSG_KSSystemInfo isInForeground:state]), @"inForeground");
    BSGDictSetSafeObject(app, @(state == UIApplicationStateActive), @"isActive");
#else
    BSGDictSetSafeObject(app, @YES, @"inForeground");
#endif
#if BSG_PLATFORM_TVOS
    BSGDictSetSafeObject(app, @"tvOS", @"type");
#elif BSG_PLATFORM_IOS
    BSGDictSetSafeObject(app, @"iOS", @"type");
#endif
    BSGDictSetSafeObject(cache, app, @"app");

    NSMutableDictionary *device = [NSMutableDictionary new];
    BSGDictSetSafeObject(device, systemInfo[@BSG_KSSystemField_DeviceAppHash], @"id");
    // device[@"lowMemory"] is initially unset

    BSGDictSetSafeObject(device, systemInfo[@BSG_KSSystemField_OSVersion], @"osBuild");
    BSGDictSetSafeObject(device, systemInfo[@BSG_KSSystemField_SystemVersion], @"osVersion");
    BSGDictSetSafeObject(device, systemInfo[@BSG_KSSystemField_SystemName], @"osName");

    // Translated from 'iDeviceMaj,Min' into human-readable "iPhone X" description on the server
    BSGDictSetSafeObject(device, systemInfo[@BSG_KSSystemField_Machine], @"model");
    BSGDictSetSafeObject(device, systemInfo[@BSG_KSSystemField_Model], @"modelNumber");
    BSGDictSetSafeObject(device, @(PLATFORM_WORD_SIZE), @"wordSize");
    BSGDictSetSafeObject(device, [[NSLocale currentLocale] localeIdentifier], @"locale");

#if BSG_PLATFORM_SIMULATOR
    BSGDictSetSafeObject(device, @YES, @"simulator");
#else
    BSGDictSetSafeObject(device, @NO, @"simulator");
#endif
    BSGDictSetSafeObject(cache, device, @"device");
    return cache;
}

@end
