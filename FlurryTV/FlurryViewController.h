#import <UIKit/UIKit.h>
#import "Gl_saver.h"
#import "SettingsViewController.h"

@class MetalRenderer;
@class FlurryPresetManager;

@interface FlurryViewController : UIViewController <SettingsViewControllerDelegate>

@property (nonatomic, retain) FlurryPresetManager *presetManager;

- (void)showSettings;

@end
