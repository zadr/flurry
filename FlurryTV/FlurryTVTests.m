// FlurryTVTests.m — Lightweight unit tests for FlurryTV model and preset logic.
// Compile: clang -arch arm64 -isysroot $(xcrun --sdk appletvsimulator --show-sdk-path)
//          -fno-objc-arc -framework Foundation FlurryTV/FlurryTVTests.m FlurryUtils.m
//          FlurryTV/FlurryPresetManager.m Source/Std.c Source/Smoke.c Source/Star.c
//          Source/Spark.c Source/Particle.c Source/Texture.c Source/Gl_saver.c
//          -I. -ISource -IFlurryTV -o /tmp/FlurryTVTests && /tmp/FlurryTVTests

#import <Foundation/Foundation.h>
#import <sys/time.h>
#import "FlurryUtils.h"
#import "FlurryPresetManager.h"

// Provide CurrentTime() stub needed by Gl_saver.c (normally in FlurryViewController.m)
__private_extern__ double CurrentTime(void) {
    struct timeval time;
    gettimeofday(&time, NULL);
    return time.tv_sec + (time.tv_usec / 1000000.0);
}

static int testsPassed = 0;
static int testsFailed = 0;

#define ASSERT(expr, msg) do { \
    if (!(expr)) { \
        fprintf(stderr, "FAIL: %s (line %d): %s\n", msg, __LINE__, #expr); \
        testsFailed++; \
    } else { \
        fprintf(stderr, "PASS: %s\n", msg); \
        testsPassed++; \
    } \
} while(0)

#pragma mark - Flurry model tests

static void testFlurryInit(void) {
    @autoreleasepool {
        Flurry *f = [[Flurry alloc] init];
        ASSERT(f != nil, "Flurry alloc+init succeeds");
        ASSERT([f info] != NULL, "Flurry has non-null info");
        ASSERT([f info]->numStreams == 5, "Default stream count is 5");
        ASSERT([f info]->currentColorMode == tiedyeColorMode, "Default color mode is tiedye");
        ASSERT([f info]->streamExpansion == 100, "Default thickness is 100");
        ASSERT([f info]->star->rotSpeed == 1.0f, "Default speed is 1.0");
        ASSERT([[f name] isEqualToString:@"Flurry"], "Default name is 'Flurry'");
        [f release];
    }
}

static void testFlurryFactoryMethod(void) {
    @autoreleasepool {
        Flurry *f = [Flurry flurryWithStreams:3 colour:redColorMode thickness:200.0 speed:0.5];
        ASSERT(f != nil, "Factory method returns non-nil");
        ASSERT([f info]->numStreams == 3, "Factory: streams = 3");
        ASSERT([f info]->currentColorMode == redColorMode, "Factory: color = red");
        ASSERT([f info]->streamExpansion == 200.0f, "Factory: thickness = 200");
        ASSERT([f info]->star->rotSpeed == 0.5f, "Factory: speed = 0.5");
    }
}

static void testFlurryCopy(void) {
    @autoreleasepool {
        Flurry *original = [Flurry flurryWithStreams:7 colour:blueColorMode thickness:50.0 speed:2.0];
        [original setName:@"TestFlurry"];
        Flurry *copy = [original copy];
        ASSERT(copy != nil, "Copy returns non-nil");
        ASSERT(copy != original, "Copy is a different object");
        ASSERT([copy info]->numStreams == 7, "Copy preserves streams");
        ASSERT([copy info]->currentColorMode == blueColorMode, "Copy preserves color");
        ASSERT([copy info]->streamExpansion == 50.0f, "Copy preserves thickness");
        ASSERT([copy info]->star->rotSpeed == 2.0f, "Copy preserves speed");
        ASSERT([[copy name] isEqualToString:@"TestFlurry"], "Copy preserves name");
        [copy release];
    }
}

#pragma mark - FlurryPreset tests

static void testFlurryPresetClassic(void) {
    @autoreleasepool {
        FlurryPreset *preset = [FlurryPreset classicFlurryPreset];
        ASSERT(preset != nil, "Classic preset is non-nil");
        ASSERT([[preset name] isEqualToString:@"Classic Flurry"], "Classic preset name");
        ASSERT([[preset flurries] count] == 1, "Classic preset has 1 flurry");
    }
}

static void testFlurryPresetRGB(void) {
    @autoreleasepool {
        FlurryPreset *preset = [FlurryPreset rgbFlurryPreset];
        ASSERT([[preset name] isEqualToString:@"RGB Flurry"], "RGB preset name");
        ASSERT([[preset flurries] count] == 3, "RGB preset has 3 flurries");
    }
}

static void testFlurryPresetWater(void) {
    @autoreleasepool {
        FlurryPreset *preset = [FlurryPreset waterFlurryPreset];
        ASSERT([[preset name] isEqualToString:@"Water"], "Water preset name");
        ASSERT([[preset flurries] count] == 9, "Water preset has 9 flurries");
    }
}

static void testFlurryPresetFire(void) {
    @autoreleasepool {
        FlurryPreset *preset = [FlurryPreset fireFlurryPreset];
        ASSERT([[preset name] isEqualToString:@"Big Flurry"], "Fire/Big preset name");
        ASSERT([[preset flurries] count] == 1, "Fire preset has 1 flurry");
    }
}

static void testFlurryPresetPsychedelic(void) {
    @autoreleasepool {
        FlurryPreset *preset = [FlurryPreset psychedelicFlurryPreset];
        ASSERT([[preset name] isEqualToString:@"Psychedelic"], "Psychedelic preset name");
        ASSERT([[preset flurries] count] == 1, "Psychedelic preset has 1 flurry");
    }
}

static void testFlurryPresetCopy(void) {
    @autoreleasepool {
        FlurryPreset *original = [FlurryPreset rgbFlurryPreset];
        FlurryPreset *copy = [original copy];
        ASSERT(copy != original, "Preset copy is different object");
        ASSERT([[copy name] isEqualToString:[original name]], "Preset copy preserves name");
        ASSERT([[copy flurries] count] == [[original flurries] count], "Preset copy preserves flurry count");
        ASSERT([[copy shortcut] isEqualToString:[original shortcut]], "Preset copy preserves shortcut");
        [copy release];
    }
}

static void testFlurryPresetAddDelete(void) {
    @autoreleasepool {
        FlurryPreset *preset = [FlurryPreset classicFlurryPreset];
        NSUInteger initialCount = [[preset flurries] count];
        Flurry *extra = [[Flurry alloc] init];
        [preset addFlurry:extra];
        ASSERT([[preset flurries] count] == initialCount + 1, "Add flurry increases count");
        [preset deleteFlurry:extra];
        ASSERT([[preset flurries] count] == initialCount, "Delete flurry restores count");
        [extra release];
    }
}

#pragma mark - NSCoding (keyed archiver) tests

static void testFlurryCoding(void) {
    @autoreleasepool {
        Flurry *original = [Flurry flurryWithStreams:8 colour:rainbowColorMode thickness:300.0 speed:1.5];
        [original setName:@"CodingTest"];

        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original
                                             requiringSecureCoding:NO
                                                             error:&error];
        ASSERT(data != nil, "Flurry archives to non-nil data");
        ASSERT(error == nil, "Flurry archives without error");

        NSSet *classes = [NSSet setWithObjects:[Flurry class], [NSString class], nil];
        Flurry *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                              fromData:data
                                                                 error:&error];
        ASSERT(decoded != nil, "Flurry unarchives to non-nil");
        ASSERT(error == nil, "Flurry unarchives without error");
        ASSERT([decoded info]->numStreams == 8, "Decoded streams = 8");
        ASSERT([decoded info]->currentColorMode == rainbowColorMode, "Decoded color = rainbow");
        ASSERT([decoded info]->streamExpansion == 300.0f, "Decoded thickness = 300");
        ASSERT([decoded info]->star->rotSpeed == 1.5f, "Decoded speed = 1.5");
        ASSERT([[decoded name] isEqualToString:@"CodingTest"], "Decoded name preserved");
    }
}

static void testFlurryPresetCoding(void) {
    @autoreleasepool {
        FlurryPreset *original = [FlurryPreset rgbFlurryPreset];

        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original
                                             requiringSecureCoding:NO
                                                             error:&error];
        ASSERT(data != nil, "FlurryPreset archives to non-nil data");
        ASSERT(error == nil, "FlurryPreset archives without error");

        NSSet *classes = [NSSet setWithObjects:[FlurryPreset class], [Flurry class],
                          [NSMutableArray class], [NSArray class], [NSString class], nil];
        FlurryPreset *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                    fromData:data
                                                                       error:&error];
        ASSERT(decoded != nil, "FlurryPreset unarchives to non-nil");
        ASSERT(error == nil, "FlurryPreset unarchives without error");
        ASSERT([[decoded name] isEqualToString:@"RGB Flurry"], "Decoded preset name");
        ASSERT([[decoded flurries] count] == 3, "Decoded preset has 3 flurries");

        // Verify first flurry was decoded correctly
        Flurry *firstFlurry = [[decoded flurries] objectAtIndex:0];
        ASSERT([firstFlurry info]->numStreams == 3, "Decoded first flurry streams = 3");
        ASSERT([firstFlurry info]->currentColorMode == redColorMode, "Decoded first flurry color = red");
    }
}

#pragma mark - FlurryPresetManager tests

static void testPresetManagerInit(void) {
    @autoreleasepool {
        // Clear any existing defaults first
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presets"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"activePresetIndex"];

        FlurryPresetManager *manager = [[FlurryPresetManager alloc] init];
        ASSERT(manager != nil, "PresetManager alloc+init succeeds");
        ASSERT([[manager presets] count] == 5, "Default presets has 5 entries");
        ASSERT([manager activePreset] != nil, "Active preset is non-nil");
        ASSERT([manager activePresetIndex] == 0, "Default active index is 0");
        [manager release];
    }
}

static void testPresetManagerSaveLoad(void) {
    @autoreleasepool {
        // Clear defaults
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presets"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"activePresetIndex"];

        FlurryPresetManager *manager1 = [[FlurryPresetManager alloc] init];
        [manager1 setActivePresetIndex:2]; // Select "Water"
        [manager1 saveDefaults];
        [manager1 release];

        FlurryPresetManager *manager2 = [[FlurryPresetManager alloc] init];
        ASSERT([manager2 activePresetIndex] == 2, "Saved active index persists");
        ASSERT([[manager2 presets] count] == 5, "Preset count persists");
        ASSERT([[[manager2 activePreset] name] isEqualToString:@"Water"], "Active preset name persists");
        [manager2 release];

        // Cleanup
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presets"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"activePresetIndex"];
    }
}

static void testPresetManagerRandomSelect(void) {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presets"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"activePresetIndex"];

        FlurryPresetManager *manager = [[FlurryPresetManager alloc] init];
        srand(42); // deterministic
        [manager selectRandomPreset];
        NSInteger idx = [manager activePresetIndex];
        ASSERT(idx >= 0 && idx < 5, "Random preset index is in range");
        [manager release];
    }
}

static void testPresetManagerBoundsCheck(void) {
    @autoreleasepool {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presets"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"activePresetIndex"];

        FlurryPresetManager *manager = [[FlurryPresetManager alloc] init];
        [manager setActivePresetIndex:99]; // out of range
        ASSERT([manager activePresetIndex] == 0, "Out-of-range index doesn't change active");
        [manager setActivePresetIndex:-1]; // negative
        ASSERT([manager activePresetIndex] == 0, "Negative index doesn't change active");
        [manager release];
    }
}

#pragma mark - Color mode names test

// Replicate the colorModeNames function from SettingsViewController
static NSArray *colorModeNames(void) {
    static NSArray *names = nil;
    if (!names) {
        names = [@[@"Red", @"Magenta", @"Blue", @"Cyan", @"Green", @"Yellow",
                   @"Slow Cyclic", @"Cyclic", @"Tiedye", @"Rainbow",
                   @"White", @"Multi", @"Dark"] retain];
    }
    return names;
}

static void testColorModeNames(void) {
    @autoreleasepool {
        NSArray *names = colorModeNames();
        ASSERT([names count] == 13, "13 color mode names");
        ASSERT([[names objectAtIndex:0] isEqualToString:@"Red"], "First color is Red");
        ASSERT([[names objectAtIndex:12] isEqualToString:@"Dark"], "Last color is Dark");
        // Verify 1:1 mapping with enum
        ASSERT(redColorMode == 0, "redColorMode == 0");
        ASSERT(darkColorMode == 12, "darkColorMode == 12");
    }
}

#pragma mark - Main

int main(int argc, char *argv[]) {
    @autoreleasepool {
        OTSetup();
        srand((int)[NSDate timeIntervalSinceReferenceDate]);

        fprintf(stderr, "\n=== FlurryTV Unit Tests ===\n\n");

        // Flurry model
        testFlurryInit();
        testFlurryFactoryMethod();
        testFlurryCopy();

        // FlurryPreset
        testFlurryPresetClassic();
        testFlurryPresetRGB();
        testFlurryPresetWater();
        testFlurryPresetFire();
        testFlurryPresetPsychedelic();
        testFlurryPresetCopy();
        testFlurryPresetAddDelete();

        // NSCoding
        testFlurryCoding();
        testFlurryPresetCoding();

        // PresetManager
        testPresetManagerInit();
        testPresetManagerSaveLoad();
        testPresetManagerRandomSelect();
        testPresetManagerBoundsCheck();

        // Color mode names
        testColorModeNames();

        fprintf(stderr, "\n=== Results: %d passed, %d failed ===\n\n", testsPassed, testsFailed);

        return testsFailed > 0 ? 1 : 0;
    }
}
