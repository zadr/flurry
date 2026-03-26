// FlurryAuditLogTests.m
// Standalone tests for FlurryAuditLog
//
// Build & run:
//   clang -framework Cocoa -fobjc-arc=off FlurryAuditLog.m FlurryAuditLogTests.m -o FlurryAuditLogTests && ./FlurryAuditLogTests
//
// These tests verify the audit log singleton, entry model, ring buffer,
// notification posting, severity levels, and C bridge functions.

#import "FlurryAuditLog.h"
#include <stdio.h>

static int testsPassed = 0;
static int testsFailed = 0;

#define ASSERT(condition, msg) do { \
    if (!(condition)) { \
        fprintf(stderr, "FAIL: %s — %s\n", __func__, [msg UTF8String]); \
        testsFailed++; \
    } else { \
        testsPassed++; \
    } \
} while(0)

#pragma mark - Helper: Reset Singleton

// We need to reset the singleton between tests.
// Since sharedInstance is file-static in FlurryAuditLog.m, we access the
// entries via the public API and just create fresh log instances where needed.

#pragma mark - Test: FlurryAuditEntry

static void testEntryCreation(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditEntry *entry = [[FlurryAuditEntry alloc] initWithSeverity:FlurryAuditSeverityError
                                                                  message:@"Test error"
                                                                   source:@"TestSource"];
    ASSERT(entry != nil, @"Entry should be created");
    ASSERT([entry severity] == FlurryAuditSeverityError, @"Severity should be Error");
    ASSERT([[entry message] isEqualToString:@"Test error"], @"Message should match");
    ASSERT([[entry source] isEqualToString:@"TestSource"], @"Source should match");
    ASSERT([entry timestamp] != nil, @"Timestamp should be set");

    // Verify timestamp is recent (within last second)
    NSTimeInterval age = -[[entry timestamp] timeIntervalSinceNow];
    ASSERT(age >= 0 && age < 1.0, @"Timestamp should be recent");

    [entry release];
    [pool release];
}

static void testEntryWithWarningSeverity(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditEntry *entry = [[FlurryAuditEntry alloc] initWithSeverity:FlurryAuditSeverityWarning
                                                                  message:@"Test warning"
                                                                   source:@"WarnSource"];
    ASSERT([entry severity] == FlurryAuditSeverityWarning, @"Severity should be Warning");
    ASSERT([[entry message] isEqualToString:@"Test warning"], @"Message should match");
    ASSERT([[entry source] isEqualToString:@"WarnSource"], @"Source should match");

    [entry release];
    [pool release];
}

static void testEntryWithInfoSeverity(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditEntry *entry = [[FlurryAuditEntry alloc] initWithSeverity:FlurryAuditSeverityInfo
                                                                  message:@"Test info"
                                                                   source:@"InfoSource"];
    ASSERT([entry severity] == FlurryAuditSeverityInfo, @"Severity should be Info");

    [entry release];
    [pool release];
}

#pragma mark - Test: FlurryAuditLog Singleton

static void testSingleton(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditLog *log1 = [FlurryAuditLog sharedLog];
    FlurryAuditLog *log2 = [FlurryAuditLog sharedLog];

    ASSERT(log1 != nil, @"Shared log should not be nil");
    ASSERT(log1 == log2, @"Shared log should return the same instance");

    [pool release];
}

#pragma mark - Test: Logging and Recent Entries

static void testLogErrorAddsEntry(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditLog *log = [FlurryAuditLog sharedLog];
    NSUInteger countBefore = [[log recentEntries] count];

    [log logError:@"An error occurred" source:@"TestModule"];

    NSArray *entries = [log recentEntries];
    ASSERT([entries count] == countBefore + 1, @"Should have one more entry after logError");

    FlurryAuditEntry *last = [entries lastObject];
    ASSERT([last severity] == FlurryAuditSeverityError, @"Last entry should be Error");
    ASSERT([[last message] isEqualToString:@"An error occurred"], @"Message should match");
    ASSERT([[last source] isEqualToString:@"TestModule"], @"Source should match");

    [pool release];
}

static void testLogWarningAddsEntry(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditLog *log = [FlurryAuditLog sharedLog];
    NSUInteger countBefore = [[log recentEntries] count];

    [log logWarning:@"A warning" source:@"WarnModule"];

    NSArray *entries = [log recentEntries];
    ASSERT([entries count] == countBefore + 1, @"Should have one more entry after logWarning");

    FlurryAuditEntry *last = [entries lastObject];
    ASSERT([last severity] == FlurryAuditSeverityWarning, @"Last entry should be Warning");

    [pool release];
}

static void testLogInfoAddsEntry(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditLog *log = [FlurryAuditLog sharedLog];
    NSUInteger countBefore = [[log recentEntries] count];

    [log logInfo:@"Some info" source:@"InfoModule"];

    NSArray *entries = [log recentEntries];
    ASSERT([entries count] == countBefore + 1, @"Should have one more entry after logInfo");

    FlurryAuditEntry *last = [entries lastObject];
    ASSERT([last severity] == FlurryAuditSeverityInfo, @"Last entry should be Info");

    [pool release];
}

#pragma mark - Test: Ring Buffer Cap

static void testRingBufferCap(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditLog *log = [FlurryAuditLog sharedLog];

    // Log enough entries to exceed the 100 cap
    // First, count how many are already in there
    NSUInteger existingCount = [[log recentEntries] count];
    NSUInteger toAdd = 100 - existingCount + 10; // overshoot by 10

    for (NSUInteger i = 0; i < toAdd; i++)
    {
        [log logInfo:[NSString stringWithFormat:@"Entry %lu", (unsigned long)i] source:@"RingTest"];
    }

    NSArray *entries = [log recentEntries];
    ASSERT([entries count] == 100, @"Ring buffer should cap at 100 entries");

    // Verify the oldest entries were dropped (the first entry should NOT be "Entry 0")
    FlurryAuditEntry *first = [entries objectAtIndex:0];
    ASSERT(![[first message] isEqualToString:@"Entry 0"],
           @"Oldest entry should have been evicted from ring buffer");

    // Verify the last entry is the most recent
    FlurryAuditEntry *last = [entries lastObject];
    NSString *expectedLast = [NSString stringWithFormat:@"Entry %lu", (unsigned long)(toAdd - 1)];
    ASSERT([[last message] isEqualToString:expectedLast],
           @"Last entry should be the most recently added");

    [pool release];
}

#pragma mark - Test: recentEntries Returns a Copy

static void testRecentEntriesReturnsCopy(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    FlurryAuditLog *log = [FlurryAuditLog sharedLog];
    NSArray *entries1 = [log recentEntries];
    NSArray *entries2 = [log recentEntries];

    // They should be equal in content but not the same object
    ASSERT(entries1 != entries2, @"recentEntries should return a new array each time");
    ASSERT([entries1 isEqualToArray:entries2], @"Both arrays should contain the same entries");

    [pool release];
}

#pragma mark - Test: Notification Posting

static BOOL notificationReceived = NO;
static FlurryAuditEntry *receivedEntry = nil;

static void notificationHandler(NSNotification *notification)
{
    notificationReceived = YES;
    receivedEntry = [[[notification userInfo] objectForKey:@"entry"] retain];
}

@interface TestNotificationObserver : NSObject
- (void)handleNotification:(NSNotification *)notification;
@end

@implementation TestNotificationObserver
- (void)handleNotification:(NSNotification *)notification
{
    notificationReceived = YES;
    [receivedEntry release];
    receivedEntry = [[[notification userInfo] objectForKey:@"entry"] retain];
}
@end

static void testNotificationPostedForError(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    notificationReceived = NO;
    [receivedEntry release];
    receivedEntry = nil;

    TestNotificationObserver *observer = [[TestNotificationObserver alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(handleNotification:)
                                                 name:FlurryAuditErrorNotification
                                               object:nil];

    [[FlurryAuditLog sharedLog] logError:@"Notification test error" source:@"NotifTest"];

    ASSERT(notificationReceived == YES, @"Notification should be posted for errors");
    ASSERT(receivedEntry != nil, @"Notification should contain entry in userInfo");
    ASSERT([receivedEntry severity] == FlurryAuditSeverityError, @"Entry severity should be Error");
    ASSERT([[receivedEntry message] isEqualToString:@"Notification test error"], @"Entry message should match");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    [observer release];
    [receivedEntry release];
    receivedEntry = nil;

    [pool release];
}

static void testNotificationPostedForWarning(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    notificationReceived = NO;
    [receivedEntry release];
    receivedEntry = nil;

    TestNotificationObserver *observer = [[TestNotificationObserver alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(handleNotification:)
                                                 name:FlurryAuditErrorNotification
                                               object:nil];

    [[FlurryAuditLog sharedLog] logWarning:@"Notification test warning" source:@"NotifTest"];

    ASSERT(notificationReceived == YES, @"Notification should be posted for warnings");
    ASSERT(receivedEntry != nil, @"Notification should contain entry in userInfo");
    ASSERT([receivedEntry severity] == FlurryAuditSeverityWarning, @"Entry severity should be Warning");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    [observer release];
    [receivedEntry release];
    receivedEntry = nil;

    [pool release];
}

static void testNoNotificationForInfo(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    notificationReceived = NO;
    [receivedEntry release];
    receivedEntry = nil;

    TestNotificationObserver *observer = [[TestNotificationObserver alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(handleNotification:)
                                                 name:FlurryAuditErrorNotification
                                               object:nil];

    [[FlurryAuditLog sharedLog] logInfo:@"Info message" source:@"NotifTest"];

    ASSERT(notificationReceived == NO, @"Notification should NOT be posted for info-level entries");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    [observer release];

    [pool release];
}

#pragma mark - Test: C Bridge Functions

static void testCBridgeLogError(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    notificationReceived = NO;
    [receivedEntry release];
    receivedEntry = nil;

    TestNotificationObserver *observer = [[TestNotificationObserver alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(handleNotification:)
                                                 name:FlurryAuditErrorNotification
                                               object:nil];

    FlurryLogError("C bridge error", "CTest");

    ASSERT(notificationReceived == YES, @"C bridge FlurryLogError should post notification");
    ASSERT(receivedEntry != nil, @"Should have received entry via C bridge");
    ASSERT([receivedEntry severity] == FlurryAuditSeverityError, @"C bridge entry should be Error");
    ASSERT([[receivedEntry message] isEqualToString:@"C bridge error"], @"C bridge message should match");
    ASSERT([[receivedEntry source] isEqualToString:@"CTest"], @"C bridge source should match");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    [observer release];
    [receivedEntry release];
    receivedEntry = nil;

    [pool release];
}

static void testCBridgeLogWarning(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    notificationReceived = NO;
    [receivedEntry release];
    receivedEntry = nil;

    TestNotificationObserver *observer = [[TestNotificationObserver alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(handleNotification:)
                                                 name:FlurryAuditErrorNotification
                                               object:nil];

    FlurryLogWarning("C bridge warning", "CTest");

    ASSERT(notificationReceived == YES, @"C bridge FlurryLogWarning should post notification");
    ASSERT(receivedEntry != nil, @"Should have received entry via C bridge");
    ASSERT([receivedEntry severity] == FlurryAuditSeverityWarning, @"C bridge entry should be Warning");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    [observer release];
    [receivedEntry release];
    receivedEntry = nil;

    [pool release];
}

#pragma mark - Test: Notification Constant

static void testNotificationConstantValue(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    ASSERT(FlurryAuditErrorNotification != nil, @"Notification constant should not be nil");
    ASSERT([FlurryAuditErrorNotification isEqualToString:@"FlurryAuditErrorNotification"],
           @"Notification constant should have expected string value");

    [pool release];
}

#pragma mark - Test: Entry Memory (Dealloc Doesn't Crash)

static void testEntryDealloc(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Create and release many entries to verify no memory issues
    for (int i = 0; i < 100; i++)
    {
        FlurryAuditEntry *entry = [[FlurryAuditEntry alloc] initWithSeverity:FlurryAuditSeverityInfo
                                                                      message:[NSString stringWithFormat:@"Msg %d", i]
                                                                       source:[NSString stringWithFormat:@"Src %d", i]];
        // Access all properties to ensure they are valid
        (void)[entry timestamp];
        (void)[entry severity];
        (void)[entry message];
        (void)[entry source];
        [entry release];
    }

    ASSERT(YES, @"Entry alloc/dealloc cycle should not crash");

    [pool release];
}

#pragma mark - Test: Severity Enum Values

static void testSeverityEnumValues(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Verify enum ordering (Info < Warning < Error)
    ASSERT(FlurryAuditSeverityInfo < FlurryAuditSeverityWarning,
           @"Info severity should be less than Warning");
    ASSERT(FlurryAuditSeverityWarning < FlurryAuditSeverityError,
           @"Warning severity should be less than Error");

    [pool release];
}

#pragma mark - Main

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    fprintf(stderr, "=== FlurryAuditLog Test Suite ===\n\n");

    // Entry tests
    testEntryCreation();
    testEntryWithWarningSeverity();
    testEntryWithInfoSeverity();
    testEntryDealloc();
    testSeverityEnumValues();

    // Singleton test
    testSingleton();

    // Logging tests
    testLogErrorAddsEntry();
    testLogWarningAddsEntry();
    testLogInfoAddsEntry();

    // Ring buffer test
    testRingBufferCap();

    // Recent entries copy test
    testRecentEntriesReturnsCopy();

    // Notification tests
    testNotificationPostedForError();
    testNotificationPostedForWarning();
    testNoNotificationForInfo();

    // Notification constant test
    testNotificationConstantValue();

    // C bridge tests
    testCBridgeLogError();
    testCBridgeLogWarning();

    fprintf(stderr, "\n=== Results: %d passed, %d failed ===\n", testsPassed, testsFailed);

    [pool release];

    return testsFailed > 0 ? 1 : 0;
}
