/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAConfig.h"
#import "UAAnalytics+Internal.h"
#import "UAHTTPConnection+Internal.h"
#import "UAAnalyticsTest.h"
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAKeychainUtils.h"
#import "UAPush+Internal.h"
#import "UAPreferenceDataStore.h"
#import "UAirship.h"
#import "UAAnalyticsDBManager.h"

@interface UAAnalyticsTest()
@property (nonatomic, strong) UAAnalytics *analytics;

@property (nonatomic, strong) id mockedKeychainClass;
@property (nonatomic, strong) id mockLocaleClass;
@property (nonatomic, strong) id mockTimeZoneClass;
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockDBManager;

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@property (nonatomic, strong) NSValue *noValue;
@property (nonatomic, strong) NSValue *yesValue;
@end

@implementation UAAnalyticsTest


- (void)setUp {
    [super setUp];
    
    self.mockedKeychainClass = [OCMockObject mockForClass:[UAKeychainUtils class]];
    [[[self.mockedKeychainClass stub] andReturn:@"some-device-ID"] getDeviceID];

    self.mockLocaleClass = [OCMockObject mockForClass:[NSLocale class]];
    self.mockTimeZoneClass = [OCMockObject mockForClass:[NSTimeZone class]];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"test.analytics"];

    self.mockDBManager = [OCMockObject niceMockForClass:[UAAnalyticsDBManager class]];

    UAConfig *config = [[UAConfig alloc] init];
    self.analytics = [UAAnalytics analyticsWithConfig:config dataStore:self.dataStore];
    self.analytics.analyticDBManager = self.mockDBManager;
 }

- (void)tearDown {
    [super tearDown];

    [self.mockAirship stopMocking];
    [self.mockedKeychainClass stopMocking];
    [self.mockLocaleClass stopMocking];
    [self.mockTimeZoneClass stopMocking];
    [self.mockPush stopMocking];
    [self.mockDBManager stopMocking];

    [self.dataStore removeAll];
}

- (void)testRequestTimezoneHeader {
    [self setTimeZone:@"America/New_York"];
    
    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Timezone"], @"America/New_York", @"Wrong timezone in event headers");
}

- (void)testRequestLocaleHeadersFullCode {
    [self setCurrentLocale:@"en_US_POSIX"];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Language"], @"en", @"Wrong local language code in event headers");
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Country"],  @"US", @"Wrong local country code in event headers");
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Variant"],  @"POSIX", @"Wrong local variant in event headers");
}

- (void)testAnalyticRequestLocationHeadersPartialCode {
    [self setCurrentLocale:@"de"];
    
    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Language"], @"de", @"Wrong local language code in event headers");
    XCTAssertNil([headers objectForKey:@"X-UA-Locale-Country"], @"Wrong local country code in event headers");
    XCTAssertNil([headers objectForKey:@"X-UA-Locale-Variant"], @"Wrong local variant in event headers");
}

- (void)testRequestEmptyPushAddressHeader {
    [[[self.mockPush stub] andReturn:nil] deviceToken];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertNil([headers objectForKey:@"X-UA-Push-Address"], @"Device token should be null in event headers");
}

- (void)testRequestPushAddressHeader {
    NSString *deviceTokenString = @"123456789012345678901234567890";
    [[[self.mockPush stub] andReturn:deviceTokenString] deviceToken];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Push-Address"], deviceTokenString, @"Wrong device token in event headers");
}

- (void)testRequestChannelIDHeader {
    NSString *channelIDString = @"someChannelID";
    [[[self.mockPush stub] andReturn:channelIDString] channelID];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqualObjects([headers objectForKey:@"X-UA-Channel-ID"], channelIDString, @"Wrong channel ID in event headers");
}

- (void)testRequestChannelOptInNoHeader {

    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(NO)] userPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqual([headers objectForKey:@"X-UA-Channel-Opted-In"], @"false");
}

- (void)testRequestChannelOptInYesHeader {
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] userPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqual([headers objectForKey:@"X-UA-Channel-Opted-In"], @"true");
}

- (void)testRequestChannelBackgroundEnabledNoHeader {
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(NO)] backgroundPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqual([headers objectForKey:@"X-UA-Channel-Background-Enabled"], @"false");
}

- (void)testRequestChannelBackgroundEnabledYesHeader {
    [[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(YES)] backgroundPushNotificationsAllowed];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    XCTAssertEqual([headers objectForKey:@"X-UA-Channel-Background-Enabled"], @"true");
}

- (void)restoreSavedUploadEventSettingsEmptyDataStore {
    [self.analytics restoreSavedUploadEventSettings];

    // Should try to set the values to 0 and the setter should normalize them to the min values.
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes, @"maxTotalDBSize is setting an incorrect value when trying to set the value to 0");
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes, @"maxBatchSize is setting an incorrect value when trying to set the value to 0");
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds, @"maxWait is setting an incorrect value when trying to set the value to 0");
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds, @"minBatchInterval is setting an incorrect value when trying to set the value to 0");
}

- (void)restoreSavedUploadEventSettingsExistingData {

    // Set valid data
    [self.dataStore setValue:@(kMinTotalDBSizeBytes + 5) forKey:kMaxTotalDBSizeUserDefaultsKey];
    [self.dataStore setValue:@(kMinBatchSizeBytes + 5) forKey:kMaxBatchSizeUserDefaultsKey];
    [self.dataStore setValue:@(kMinWaitSeconds + 5) forKey:kMaxWaitUserDefaultsKey];
    [self.dataStore setValue:@(kMinBatchIntervalSeconds + 5) forKey:kMinBatchIntervalUserDefaultsKey];

    [self.analytics restoreSavedUploadEventSettings];

    // Should try to set the values to 0 and the setter should normalize them to the min values.
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes + 5, @"maxTotalDBSize value did not restore properly");
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes + 5, @"maxBatchSize value did not restore properly");
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds + 5, @"maxWait value did not restore properly");
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds + 5, @"minBatchInterval value did not restore properly");
}

- (void)testSaveUploadEventSettings {
    [self.analytics saveUploadEventSettings];

    XCTAssertEqual(self.analytics.maxTotalDBSize, [[self.dataStore valueForKey:kMaxTotalDBSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(self.analytics.maxBatchSize, [[self.dataStore valueForKey:kMaxBatchSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(self.analytics.maxWait,[[self.dataStore valueForKey:kMaxWaitUserDefaultsKey] integerValue]);
    XCTAssertEqual(self.analytics.minBatchInterval,[[self.dataStore valueForKey:kMinBatchIntervalUserDefaultsKey] integerValue]);
}

- (void)testUpdateAnalyticsParameters {
    // Create headers with response values for the event header settings
    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithCapacity:4];
    [headers setValue:[NSNumber numberWithInt:11] forKey:@"X-UA-Max-Total"];
    [headers setValue:[NSNumber numberWithInt:11] forKey:@"X-UA-Max-Batch"];
    [headers setValue:[NSNumber numberWithInt:8*24*3600] forKey:@"X-UA-Max-Wait"];
    [headers setValue:[NSNumber numberWithInt:62] forKey:@"X-UA-Min-Batch-Interval"];

    id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];
    [[[mockResponse stub] andReturn:headers] allHeaderFields];

    [self.analytics updateAnalyticsParametersWithHeaderValues:mockResponse];

    // Make sure all the expected settings are set to the current analytics properties
    XCTAssertEqual(11 * 1024, [[self.dataStore valueForKey:kMaxTotalDBSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(11 * 1024, [[self.dataStore valueForKey:kMaxBatchSizeUserDefaultsKey] integerValue]);
    XCTAssertEqual(8*24*3600, [[self.dataStore valueForKey:kMaxWaitUserDefaultsKey] integerValue]);
    XCTAssertEqual(62,[[self.dataStore valueForKey:kMinBatchIntervalUserDefaultsKey] integerValue]);

    [mockResponse stopMocking];
}

- (void)testSetMaxTotalDBSize {
    // Set a value higher then the max, should set to the max
    self.analytics.maxTotalDBSize = kMaxTotalDBSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMaxTotalDBSizeBytes, @"maxTotalDBSize is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.maxTotalDBSize = kMinTotalDBSizeBytes - 1;
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes, @"maxTotalDBSize is able to be set below the min value");

    // Set a value between
    self.analytics.maxTotalDBSize = kMinTotalDBSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxTotalDBSize, kMinTotalDBSizeBytes + 1, @"maxTotalDBSize is unable to be set to a valid value");
}

- (void)testSetMaxBatchSize {
    // Set a value higher then the max, should set to the max
    self.analytics.maxBatchSize = kMaxBatchSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxBatchSize, kMaxBatchSizeBytes, @"maxBatchSize is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.maxBatchSize = kMinBatchSizeBytes - 1;
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes, @"maxBatchSize is able to be set below the min value");

    // Set a value between
    self.analytics.maxBatchSize = kMinBatchSizeBytes + 1;
    XCTAssertEqual(self.analytics.maxBatchSize, kMinBatchSizeBytes + 1, @"maxBatchSize is unable to be set to a valid value");
}

- (void)testSetMaxWait {
    // Set a value higher then the max, should set to the max
    self.analytics.maxWait = kMaxWaitSeconds + 1;
    XCTAssertEqual(self.analytics.maxWait, kMaxWaitSeconds, @"maxWait is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.maxWait = kMinWaitSeconds - 1;
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds, @"maxWait is able to be set below the min value");

    // Set a value between
    self.analytics.maxWait = kMinWaitSeconds + 1;
    XCTAssertEqual(self.analytics.maxWait, kMinWaitSeconds + 1, @"maxWait is unable to be set to a valid value");
}

- (void)testSetMinBatchInterval {
    // Set a value higher then the max, should set to the max
    self.analytics.minBatchInterval = kMaxBatchIntervalSeconds + 1;
    XCTAssertEqual(self.analytics.minBatchInterval, kMaxBatchIntervalSeconds, @"minBatchInterval is able to be set above the max value");

    // Set a value lower then then min, should set to the min
    self.analytics.minBatchInterval = kMinBatchIntervalSeconds - 1;
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds, @"minBatchInterval is able to be set below the min value");

    // Set a value between
    self.analytics.minBatchInterval = kMinBatchIntervalSeconds + 1;
    XCTAssertEqual(self.analytics.minBatchInterval, kMinBatchIntervalSeconds + 1, @"minBatchInterval is unable to be set to a valid value");
}

- (void)testIsEventValid {
    // Create a valid dictionary
    NSMutableDictionary *event = [self createValidEvent];
    XCTAssertTrue([self.analytics isEventValid:event], @"isEventValid should be true for a valid event");
}

- (void)testIsEventValidEmptyDictionary {
    NSMutableDictionary *invalidEventData = [NSMutableDictionary dictionary];
    XCTAssertFalse([self.analytics isEventValid:invalidEventData], @"isEventValid should be false for an empty dictionary");
}

- (void)testIsEventValidInvalidValues {
    NSArray *eventKeysToTest = @[@"event_id", @"session_id", @"type", @"time", @"event_size", @"data"];

    for (NSString *key in eventKeysToTest) {
        // Create a valid event
        NSMutableDictionary *event = [self createValidEvent];

        // Make the value invalid - empty array is an invalid type for all the fields
        [event setValue:@[] forKey:key];
        XCTAssertFalse([self.analytics isEventValid:event], @"isEventValid did not detect invalid %@", key);


        // Remove the value
        [event setValue:NULL forKey:key];
        XCTAssertFalse([self.analytics isEventValid:event], @"isEventValid did not detect empty %@", key);
    }
}

/**
 * Test disabling analytics will result in deleting the database.
 */
- (void)testDisablingAnalytics {
    [[self.mockDBManager expect] resetDB];
    self.analytics.enabled = NO;

    [self.mockDBManager verify];
    XCTAssertFalse(self.analytics.enabled);
}

/**
 * Test the default value of enabled is YES and will not reset the value to YES
 * on init if its set to NO.
 */
- (void)testDefaultAnalyticsEnableValue {
    XCTAssertTrue(self.analytics.enabled);
    self.analytics.enabled = NO;

    // Recreate analytics and see if its still disabled
    self.analytics = [UAAnalytics analyticsWithConfig:[UAConfig config] dataStore:self.dataStore];

    XCTAssertFalse(self.analytics.enabled);
}

/**
 * Test isEnabled always returns YES only if UAConfig enables analytics and the
 * runtime setting is enabled.
 */
- (void)testIsEnabled {
    self.analytics.enabled = YES;
    XCTAssertTrue(self.analytics.enabled);

    self.analytics.enabled = NO;
    XCTAssertFalse(self.analytics.enabled);
}

/**
 * Test isEnabled only returns NO when UAConfig disables analytics.
 */
- (void)testIsEnabledConfigOverride {
    UAConfig *config = [UAConfig config];
    config.analyticsEnabled = NO;
    self.analytics = [UAAnalytics analyticsWithConfig:config dataStore:self.dataStore];

    self.analytics.enabled = YES;
    XCTAssertFalse(self.analytics.enabled);

    self.analytics.enabled = NO;
    XCTAssertFalse(self.analytics.enabled);
}

- (void)setCurrentLocale:(NSString *)localeCode {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:localeCode];

    [[[self.mockLocaleClass stub] andReturn:locale] currentLocale];
}

- (void)setTimeZone:(NSString *)name {
    NSTimeZone *timeZone = [[NSTimeZone alloc] initWithName:name];
    
    [[[self.mockTimeZoneClass stub] andReturn:timeZone] defaultTimeZone];
}

-(NSMutableDictionary *) createValidEvent {
    return [@{@"event_id": @"some-event-ID",
             @"data": [NSMutableData dataWithCapacity:1],
             @"session_id": @"some-session-ID",
             @"type": @"base",
             @"time":[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]],
             @"event_size":@"40"} mutableCopy];
}

@end
