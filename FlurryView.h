#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import "Gl_saver.h"
#import "FlurryUtils.h"
#import "PresetManager.h"

@class MetalRenderer;

@interface FlurryView : ScreenSaverView
{
    MetalRenderer *_renderer;
    BOOL randomisePreset, randomiseDisplay;
    NSTimer *tableRefreshTimer;
    PresetManager *presetManager;
    double _oldFrameTime;
    
    BOOL garbageHack;

    IBOutlet id presetMenuSpace;
    IBOutlet NSTableView *flurryTable;
    IBOutlet id streamCountSlider;
    IBOutlet id thicknessSlider;
    IBOutlet id speedSlider;
    IBOutlet id colourMenu;
    IBOutlet id window;
    IBOutlet id randomPresetCheckbox;
    IBOutlet id randomDisplayCheckbox;
}

- (void)writeDefaults;

- (IBAction)testNow:(id)sender;
- (IBAction)displayReadMe:(id)sender;
- (IBAction)addFlurry:(id)sender;
- (IBAction)deleteFlurry:(id)sender;
- (IBAction)saveAndCloseSheet:(id)sender;
- (IBAction)somethingChanged:(id)sender;
@end
