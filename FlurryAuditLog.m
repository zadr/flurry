// FlurryAuditLog.m
// Flurry Screensaver — Audit Logging

#import "FlurryAuditLog.h"

NSString * const FlurryAuditErrorNotification = @"FlurryAuditErrorNotification";

static const NSUInteger kMaxEntries = 100;

#pragma mark - FlurryAuditEntry

@implementation FlurryAuditEntry

- (id)initWithSeverity:(FlurryAuditSeverity)sev message:(NSString *)msg source:(NSString *)src
{
    if (self = [super init])
    {
        timestamp = [[NSDate alloc] init];
        severity = sev;
        message = [msg copy];
        source = [src copy];
    }
    return self;
}

- (void)dealloc
{
    [timestamp release];
    [message release];
    [source release];
    [super dealloc];
}

- (NSDate *)timestamp { return timestamp; }
- (FlurryAuditSeverity)severity { return severity; }
- (NSString *)message { return message; }
- (NSString *)source { return source; }

@end

#pragma mark - FlurryAuditLog

@implementation FlurryAuditLog

static FlurryAuditLog *sharedInstance = nil;

+ (FlurryAuditLog *)sharedLog
{
    if (sharedInstance == nil)
    {
        sharedInstance = [[FlurryAuditLog alloc] init];
    }
    return sharedInstance;
}

- (id)init
{
    if (self = [super init])
    {
        _entries = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_entries release];
    [super dealloc];
}

- (void)logEntryWithSeverity:(FlurryAuditSeverity)sev message:(NSString *)message source:(NSString *)source
{
    FlurryAuditEntry *entry = [[FlurryAuditEntry alloc] initWithSeverity:sev
                                                                 message:message
                                                                  source:source];

    // Ring buffer: drop oldest when full
    if ([_entries count] >= kMaxEntries)
    {
        [_entries removeObjectAtIndex:0];
    }
    [_entries addObject:entry];

    // NSLog for Console.app / log stream visibility
    NSString *severityString;
    switch (sev)
    {
        case FlurryAuditSeverityError:   severityString = @"ERROR";   break;
        case FlurryAuditSeverityWarning: severityString = @"WARNING"; break;
        case FlurryAuditSeverityInfo:    severityString = @"INFO";    break;
        default:                         severityString = @"UNKNOWN"; break;
    }
    NSLog(@"[Flurry/%@] %@: %@", source, severityString, message);

    // Post notification for warnings and errors so the GUI can show an alert
    if (sev == FlurryAuditSeverityWarning || sev == FlurryAuditSeverityError)
    {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:entry forKey:@"entry"];
        [[NSNotificationCenter defaultCenter] postNotificationName:FlurryAuditErrorNotification
                                                            object:self
                                                          userInfo:userInfo];
    }

    [entry release];
}

- (void)logError:(NSString *)message source:(NSString *)source
{
    [self logEntryWithSeverity:FlurryAuditSeverityError message:message source:source];
}

- (void)logWarning:(NSString *)message source:(NSString *)source
{
    [self logEntryWithSeverity:FlurryAuditSeverityWarning message:message source:source];
}

- (void)logInfo:(NSString *)message source:(NSString *)source
{
    [self logEntryWithSeverity:FlurryAuditSeverityInfo message:message source:source];
}

- (NSArray *)recentEntries
{
    return [NSArray arrayWithArray:_entries];
}

@end

#pragma mark - C Bridge Functions

void FlurryLogError(const char *message, const char *source)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[FlurryAuditLog sharedLog] logError:[NSString stringWithUTF8String:message]
                                  source:[NSString stringWithUTF8String:source]];
    [pool release];
}

void FlurryLogWarning(const char *message, const char *source)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[FlurryAuditLog sharedLog] logWarning:[NSString stringWithUTF8String:message]
                                    source:[NSString stringWithUTF8String:source]];
    [pool release];
}
