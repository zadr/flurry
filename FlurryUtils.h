#import <TargetConditionals.h>

#if TARGET_OS_TV
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#endif

#import "Gl_saver.h"

#define RANDOM_PRESET_KEY @"randomPreset"
#define RANDOM_DISPLAY_KEY @"randomDisplay"
#define VERSION_STRING [[[NSBundle mainBundle] infoDictionary] \
								objectForKey:@"CFBundleShortVersionString"]

#define UPDATE_COLOUR_NOTIF @"updateColours"
#define COLOUR_REFRESH_INTERVAL 0.1

#if TARGET_OS_TV
@interface Flurry : NSObject <NSSecureCoding, NSCopying> {
#else
@interface Flurry : NSObject <NSCoding, NSCopying> {
#endif
	global_info_t *flurry_info;
	NSString *name;
	unsigned int randomFactor;
	unsigned int screens;
}

+ (Flurry *)flurryWithStreams:(int)s colour:(ColorModes)c thickness:(float)t speed:(float)sp;

- (NSString *)name;
- (void)setName:(NSString *)newName;
- (NSNumber *)streamCount;
- (void)setStreamCount:(NSNumber *)newStreamCount;
- (global_info_t *)info;

#if !TARGET_OS_TV
- (id)colour;
- (void)randomiseDisplays:(BOOL)goRandom;
- (void)setDraws:(BOOL)doesDraw onScreen:(int)screen;
- (BOOL)shouldDrawOnScreenIndex:(int)index randomise:(BOOL)randomise;
- (BOOL)shouldDrawOnScreen:(NSScreen *)screen randomise:(BOOL)randomise;
- (BOOL)shouldDrawInView:(NSView *)view randomise:(BOOL)randomise;
#endif
@end

#if TARGET_OS_TV
@interface FlurryPreset : NSObject <NSSecureCoding, NSCopying> {
#else
@interface FlurryPreset : NSObject <NSCoding, NSCopying> {
#endif
	NSString *name;
	NSMutableArray *flurries;
	NSString *shortcut;
}

+ (FlurryPreset *)classicFlurryPreset;
+ (FlurryPreset *)rgbFlurryPreset;
+ (FlurryPreset *)waterFlurryPreset;
+ (FlurryPreset *)fireFlurryPreset;
+ (FlurryPreset *)psychedelicFlurryPreset;

- (void)addFlurry:(Flurry *)flurry;
- (void)deleteFlurry:(Flurry *)flurry;
- (NSArray *)flurries;
- (NSString *)name;
- (void)setName:(NSString *)newName;
- (NSString *)shortcut;
- (void)setShortcut:(NSString *)newShortcut;
@end

#if !TARGET_OS_TV
@interface FlurryColour : NSColor {
	Flurry *flurry;
}
- (Flurry *)flurry;
- (void)setFlurry:(Flurry *)new_flurry;
@end

@interface ColourCell : NSCell { }
@end
#endif
