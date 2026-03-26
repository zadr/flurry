// FlurryAuditLog.h
// Flurry Screensaver — Audit Logging
//
// Centralized audit log for surfacing errors/warnings on-screen (via NSAlert
// in the configuration sheet) and in Console.app / Terminal:
//
//   log stream --process ScreenSaverEngine --predicate 'eventMessage CONTAINS "Flurry"'
//   or open Console.app and search for "Flurry"

#import <Cocoa/Cocoa.h>

#pragma mark - Severity

typedef enum {
    FlurryAuditSeverityInfo,
    FlurryAuditSeverityWarning,
    FlurryAuditSeverityError
} FlurryAuditSeverity;

#pragma mark - Notification

extern NSString * const FlurryAuditErrorNotification;
// userInfo key: @"entry" → FlurryAuditEntry *

#pragma mark - FlurryAuditEntry

@interface FlurryAuditEntry : NSObject
{
    NSDate *timestamp;
    FlurryAuditSeverity severity;
    NSString *message;
    NSString *source;
}
- (id)initWithSeverity:(FlurryAuditSeverity)sev message:(NSString *)msg source:(NSString *)src;
- (NSDate *)timestamp;
- (FlurryAuditSeverity)severity;
- (NSString *)message;
- (NSString *)source;
@end

#pragma mark - FlurryAuditLog (Singleton)

@interface FlurryAuditLog : NSObject
{
    NSMutableArray *_entries;
}
+ (FlurryAuditLog *)sharedLog;

- (void)logError:(NSString *)message source:(NSString *)source;
- (void)logWarning:(NSString *)message source:(NSString *)source;
- (void)logInfo:(NSString *)message source:(NSString *)source;

- (NSArray *)recentEntries;
@end

#pragma mark - C Bridge (for use from .c files)

#ifdef __cplusplus
extern "C" {
#endif

void FlurryLogError(const char *message, const char *source);
void FlurryLogWarning(const char *message, const char *source);

#ifdef __cplusplus
}
#endif
