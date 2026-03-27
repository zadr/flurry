#import <UIKit/UIKit.h>

@class FlurryPresetManager;

@protocol SettingsViewControllerDelegate <NSObject>
- (void)settingsDidChangeWithRandomise:(BOOL)randomise;
@end

@interface SettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, assign) id<SettingsViewControllerDelegate> delegate;
@property (nonatomic, retain) FlurryPresetManager *presetManager;
@property (nonatomic, assign) BOOL randomisePreset;

@end
