#import <Foundation/Foundation.h>
#import "FlurryUtils.h"

@interface FlurryPresetManager : NSObject {
    NSMutableArray *_presets;
    NSInteger _activePresetIndex;
}

@property (nonatomic, readonly) NSArray *presets;
@property (nonatomic, readonly) FlurryPreset *activePreset;
@property (nonatomic, assign) NSInteger activePresetIndex;

- (void)selectRandomPreset;
- (void)saveDefaults;
- (void)loadDefaults;

@end
