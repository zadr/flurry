#import "FlurryViewController.h"
#import <sys/time.h>
#import <QuartzCore/CAMetalLayer.h>

#include "Texture.h"
#include "MetalRenderer.h"
#include "Smoke.h"

#import "FlurryPresetManager.h"
#import "SettingsViewController.h"

__private_extern__ double CurrentTime(void)
{
    struct timeval time;
    gettimeofday(&time, NULL);
    return time.tv_sec + (time.tv_usec / 1000000.0);
}

// Maximum vertex count for star/spark rendering
// Star: 30 rotations * 12 verts = 360
// Sparks: 12 sparks * 12 rotations * 12 verts = 1728
// Total worst case: ~2100 verts per flurry
#define MAX_UNTEXTURED_VERTS 4096

@implementation FlurryViewController {
    CAMetalLayer *_metalLayer;
    MetalRenderer *_renderer;
    CADisplayLink *_displayLink;
    FlurryPresetManager *_presetManager;
    double _oldFrameTime;
    BOOL _garbageHack;
    BOOL _randomisePreset;
}

- (void)dealloc {
    [_displayLink invalidate];
    [_renderer release];
    [_presetManager release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    _metalLayer = [CAMetalLayer layer];
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    _metalLayer.device = device;
    [device release];
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = NO;
    _metalLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:_metalLayer];

    _renderer = [[MetalRenderer alloc] initWithLayer:_metalLayer];
    _presetManager = [[FlurryPresetManager alloc] init];

    _randomisePreset = [[NSUserDefaults standardUserDefaults] boolForKey:RANDOM_PRESET_KEY];

    OTSetup();
    srand((int)[NSDate timeIntervalSinceReferenceDate]);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startAnimation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self stopAnimation];
    [super viewWillDisappear:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _metalLayer.frame = self.view.bounds;
    _metalLayer.drawableSize = self.view.bounds.size;
    [_renderer resize:self.view.bounds.size];
}

- (void)startAnimation {
    int i;

    unsigned char *texData = GenerateParticleTextureData();
    [_renderer createParticleTextureFromData:texData
                                       width:PARTICLE_TEXTURE_WIDTH
                                      height:PARTICLE_TEXTURE_HEIGHT];

    if (_randomisePreset)
        [_presetManager selectRandomPreset];

    FlurryPreset *preset = [_presetManager activePreset];
    for (i = 0; i < [[preset flurries] count]; i++) {
        Flurry *flurry = [[preset flurries] objectAtIndex:i];
        info = [flurry info];
        ResizeScene(_metalLayer.bounds.size.width, _metalLayer.bounds.size.height);
        SetupScene(info);
    }

    _garbageHack = YES;
    _oldFrameTime = TimeInSecondsSinceStart();

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderFrame:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAnimation {
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)renderFrame:(CADisplayLink *)link {
    int i;
    double newFrameTime, alpha;

    // dim the existing screen contents
    newFrameTime = TimeInSecondsSinceStart();
    alpha = 5.0 * (newFrameTime - _oldFrameTime);
    if (alpha > 0.2) alpha = 0.2;

    if (_garbageHack) {
        alpha = 1.0;
    }

    [_renderer beginFrameWithClear:_garbageHack];
    _garbageHack = NO;

    [_renderer drawDimmingQuadWithAlpha:alpha];
    _oldFrameTime = newFrameTime;

    FlurryPreset *preset = [_presetManager activePreset];
    for (i = 0; i < [[preset flurries] count]; i++) {
        Flurry *flurry = [[preset flurries] objectAtIndex:i];
        // Always draw on tvOS (single display)
        {
            info = [flurry info];
            ResizeScene(_metalLayer.bounds.size.width, _metalLayer.bounds.size.height);

            // Update physics (particles, star, sparks, smoke)
            UpdateScene();

            // Draw smoke (fills arrays, returns quad count)
            int smokeQuadCount = DrawSmoke_Scalar(info->s);
            if (smokeQuadCount > 0) {
                [_renderer drawSmokeWithVertices:(const float *)info->s->seraphimVertices
                                         colors:(const float *)info->s->seraphimColors
                                      texCoords:info->s->seraphimTextures
                                      quadCount:smokeQuadCount];
            }

            // Draw star and sparks into CPU buffers
            {
                static float untexVerts[MAX_UNTEXTURED_VERTS * 2];
                static float untexColors[MAX_UNTEXTURED_VERTS * 4];
                int totalVerts = 0;

                int starVerts = DrawStar(info->star,
                                         untexVerts + totalVerts * 2,
                                         untexColors + totalVerts * 4);
                totalVerts += starVerts;

                int j;
                for (j = 0; j < info->numStreams; j++) {
                    int sparkVerts = DrawSpark(info->spark[j],
                                               untexVerts + totalVerts * 2,
                                               untexColors + totalVerts * 4);
                    totalVerts += sparkVerts;
                }

                if (totalVerts > 0) {
                    [_renderer drawUntexturedTriangles:untexVerts
                                               colors:untexColors
                                          vertexCount:totalVerts];
                }
            }
        }
    }

    [_renderer endFrame];
}

#pragma mark - Menu button / Settings

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *press in presses) {
        if (press.type == UIPressTypeMenu) {
            [self showSettings];
            return;
        }
    }
    [super pressesBegan:presses withEvent:event];
}

- (void)showSettings {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    settingsVC.delegate = self;
    settingsVC.presetManager = _presetManager;
    settingsVC.randomisePreset = _randomisePreset;
    settingsVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [self presentViewController:settingsVC animated:YES completion:nil];
    [settingsVC release];
}

#pragma mark - SettingsViewControllerDelegate

- (void)settingsDidChangeWithRandomise:(BOOL)randomise {
    _randomisePreset = randomise;
    [[NSUserDefaults standardUserDefaults] setBool:_randomisePreset forKey:RANDOM_PRESET_KEY];
    [_presetManager saveDefaults];
    [self stopAnimation];
    [self startAnimation];
}

@end
