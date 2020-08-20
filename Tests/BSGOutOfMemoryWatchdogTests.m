#import <XCTest/XCTest.h>
#import "BSGOutOfMemoryWatchdog.h"
#import "BSG_KSSystemInfo.h"
#import "BugsnagConfiguration.h"
#import "Bugsnag.h"
#import "BugsnagClient.h"
#import "BugsnagTestConstants.h"

// Expose private identifiers for testing

@interface Bugsnag (Testing)
+ (BugsnagClient *)client;
@end

@interface BugsnagClient (Testing)
@property (nonatomic, strong) BSGOutOfMemoryWatchdog *oomWatchdog;
@property (nonatomic) NSString *codeBundleId;
@end

@interface BugsnagClient ()
- (void)start;
@end

@interface BSGOutOfMemoryWatchdog (Testing)
- (NSMutableDictionary *)generateCacheInfoWithConfig:(BugsnagConfiguration *)config;
@property(nonatomic, strong, readwrite) NSMutableDictionary *cachedFileInfo;
@end

@interface BSGOutOfMemoryWatchdogTests : XCTestCase
@property BugsnagClient *client;
@end

@implementation BSGOutOfMemoryWatchdogTests

- (void)setUp {
    [super setUp];
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.autoDetectErrors = NO;
    config.releaseStage = @"MagicalTestingTime";

    self.client = [[BugsnagClient alloc] initWithConfiguration:config];
    [self.client start];
}

- (void)testNilPathDoesNotCreateWatchdog {
    XCTAssertNil([[BSGOutOfMemoryWatchdog alloc] init]);
    XCTAssertNil([[BSGOutOfMemoryWatchdog alloc] initWithSentinelPath:nil
                                                        configuration:nil]);
}

/**
 * Test that the generated OOM report values exist and are correct (where that can be tested)
 */
- (void)testOOMFieldsSetCorrectly {
    BSGOutOfMemoryWatchdog *watchdog = [self.client oomWatchdog];

    self.client.codeBundleId = @"codeBundleIdHere";
    NSMutableDictionary *cachedFileInfo = [watchdog cachedFileInfo];
    XCTAssertNotNil(cachedFileInfo[@"app"]);
    XCTAssertNotNil(cachedFileInfo[@"device"]);
    
    NSMutableDictionary *app = cachedFileInfo[@"app"];
    XCTAssertNotNil(app[@"bundleVersion"]);
    XCTAssertNotNil(app[@"id"]);
    XCTAssertNotNil(app[@"inForeground"]);
    XCTAssertNotNil(app[@"version"]);
    XCTAssertNotNil(app[@"name"]);
    XCTAssertEqualObjects([app valueForKey:@"codeBundleId"], @"codeBundleIdHere");
    XCTAssertEqualObjects([app valueForKey:@"releaseStage"], @"MagicalTestingTime");
    
    NSMutableDictionary *device = cachedFileInfo[@"device"];
    XCTAssertNotNil(device[@"osName"]);
    XCTAssertNotNil(device[@"osBuild"]);
    XCTAssertNotNil(device[@"osVersion"]);
    XCTAssertNotNil(device[@"id"]);
    XCTAssertNotNil(device[@"model"]);
    XCTAssertNotNil(device[@"simulator"]);
    XCTAssertNotNil(device[@"wordSize"]);
    XCTAssertEqualObjects([device valueForKey:@"locale"], [[NSLocale currentLocale] localeIdentifier]);
}

@end
