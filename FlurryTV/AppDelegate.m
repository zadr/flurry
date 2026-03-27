#import "AppDelegate.h"
#import "FlurryViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // UIWindow init is deprecated in tvOS 26; the scene-based lifecycle is preferred
    // but this pre-scene pattern works for tvOS 17.0+ deployment target.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
#pragma clang diagnostic pop
    FlurryViewController *vc = [[FlurryViewController alloc] init];
    _window.rootViewController = vc;
    [vc release];
    [_window makeKeyAndVisible];
    return YES;
}

- (void)dealloc {
    [_window release];
    [super dealloc];
}

@end
