#import "FlurryPresetManager.h"

@implementation FlurryPresetManager

- (id)init {
    if (self = [super init]) {
        _presets = [[NSMutableArray alloc] init];
        [self loadDefaults];
    }
    return self;
}

- (void)dealloc {
    [_presets release];
    [super dealloc];
}

- (void)loadDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *presetsData = [defaults objectForKey:@"presets"];

    [_presets removeAllObjects];

    if (presetsData) {
        NSSet *allowedClasses = [NSSet setWithObjects:
            [NSArray class], [NSMutableArray class],
            [FlurryPreset class], [Flurry class],
            [NSString class], nil];
        NSError *error = nil;
        NSArray *unarchivedPresets = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses
                                                                        fromData:presetsData
                                                                           error:&error];
        if (unarchivedPresets && !error) {
            [_presets addObjectsFromArray:unarchivedPresets];
        }
    }

    if ([_presets count] == 0) {
        [_presets addObject:[FlurryPreset classicFlurryPreset]];
        [_presets addObject:[FlurryPreset rgbFlurryPreset]];
        [_presets addObject:[FlurryPreset waterFlurryPreset]];
        [_presets addObject:[FlurryPreset fireFlurryPreset]];
        [_presets addObject:[FlurryPreset psychedelicFlurryPreset]];
    }

    NSInteger index = [defaults integerForKey:@"activePresetIndex"];
    if (index >= 0 && index < (NSInteger)[_presets count])
        _activePresetIndex = index;
    else
        _activePresetIndex = 0;
}

- (void)saveDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_presets
                                         requiringSecureCoding:YES
                                                         error:&error];
    if (data && !error) {
        [defaults setObject:data forKey:@"presets"];
    }
    [defaults setInteger:_activePresetIndex forKey:@"activePresetIndex"];
}

- (void)selectRandomPreset {
    if ([_presets count] == 0) return;
    NSInteger index = (rand() >> 3 ^ rand() >> 6) % [_presets count];
    _activePresetIndex = index;
}

- (NSArray *)presets {
    return _presets;
}

- (FlurryPreset *)activePreset {
    if (_activePresetIndex >= 0 && _activePresetIndex < (NSInteger)[_presets count])
        return [_presets objectAtIndex:_activePresetIndex];
    return [_presets firstObject];
}

- (void)setActivePresetIndex:(NSInteger)activePresetIndex {
    if (activePresetIndex >= 0 && activePresetIndex < (NSInteger)[_presets count]) {
        _activePresetIndex = activePresetIndex;
        [self saveDefaults];
    }
}

@end
