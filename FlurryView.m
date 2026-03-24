#import "FlurryView.h"
#import <sys/time.h>
#import <QuartzCore/CAMetalLayer.h>

#include "Texture.h"
#include "MetalRenderer.h"
#include "Smoke.h"

__private_extern__ double CurrentTime(void)
{
    struct timeval time;
    
    gettimeofday(&time, NULL);
    
    return time.tv_sec + (time.tv_usec / 1000000.0); 
}

@interface MonitorCell : NSImageCell {
	NSString *index;
}
- (id)initWithIndex:(NSString *)newIndex;
@end

@implementation FlurryView

+ (void)initialize
{
	OTSetup();	// Timer for animation
	
	srand((int)[NSDate timeIntervalSinceReferenceDate]);
}

- (id)initWithFrame:(NSRect)frameRect isPreview:(BOOL) preview
{
    if (self = [super initWithFrame:frameRect isPreview:preview])
    {
        self.wantsLayer = YES;

        garbageHack = YES;
        
        presetManager = [[PresetManager alloc] init];
        [presetManager setTarget:self];
        
        randomisePreset = [[ScreenSaverDefaults defaultsForModuleWithName:@"Flurry"] 
            boolForKey:RANDOM_PRESET_KEY];
        randomiseDisplay = [[ScreenSaverDefaults defaultsForModuleWithName:@"Flurry"] 
        	boolForKey:RANDOM_DISPLAY_KEY];
    }
	
    return self;
}

- (CALayer *)makeBackingLayer
{
    return [CAMetalLayer layer];
}

- (void)dealloc
{
    [_renderer release];
    [presetManager release];
    [super dealloc];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];

    if (!_renderer) {
        _renderer = [[MetalRenderer alloc] initWithLayer:(CAMetalLayer *)self.layer];
    }
    [_renderer resize:NSSizeToCGSize(newSize)];
}

- (void)startAnimation
{
    int i;
	
    [super startAnimation];
    
    if (!_renderer) {
        _renderer = [[MetalRenderer alloc] initWithLayer:(CAMetalLayer *)self.layer];
    }

    unsigned char *texData = GenerateParticleTextureData();
    [_renderer createParticleTextureFromData:texData
                                       width:PARTICLE_TEXTURE_WIDTH
                                      height:PARTICLE_TEXTURE_HEIGHT];
    
    if (randomisePreset)
        [presetManager selectRandomPresetToView];
    
    for (i=0;i<[[[presetManager viewPreset] flurries] count];i++)
    {
        Flurry *flurry = [[[presetManager viewPreset] flurries] objectAtIndex:i];
        
        [flurry randomiseDisplays:randomiseDisplay];
        
        if ([flurry shouldDrawInView:self randomise:randomiseDisplay])
        {
            info = [flurry info];
            ResizeScene(self.frame.size.width, self.frame.size.height);
            SetupScene(info);
        }
    }
	
	garbageHack = YES;
	_oldFrameTime = TimeInSecondsSinceStart();
}

// Maximum vertex count for star/spark rendering
// Star: 30 rotations * 12 verts = 360
// Sparks: 12 sparks * 12 rotations * 12 verts = 1728
// Total worst case: ~2100 verts per flurry
#define MAX_UNTEXTURED_VERTS 4096

- (void)animateOneFrame
{
	int i;
	double newFrameTime, alpha;
	BOOL hasDrawn = NO;
	
	if ([[self window] attachedSheet])
		return;
    
	// dim the existing screen contents
    newFrameTime = TimeInSecondsSinceStart();
    alpha = 5.0 * (newFrameTime - _oldFrameTime);
    if (alpha > 0.2) alpha = 0.2;
	
	if (garbageHack) {
		alpha = 1.0;
	}

    [_renderer beginFrameWithClear:garbageHack];
	garbageHack = NO;
	
    [_renderer drawDimmingQuadWithAlpha:alpha];
    _oldFrameTime = newFrameTime;
	
	for (i=0;i<[[[presetManager viewPreset] flurries] count];i++)
	{
		Flurry *flurry = [[[presetManager viewPreset] flurries] objectAtIndex:i];
		if ([flurry shouldDrawInView:self randomise:randomiseDisplay])
		{
			info = [flurry info];
			hasDrawn = YES;
			ResizeScene(self.frame.size.width, self.frame.size.height);
			
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

- (void)stopAnimation
{
    [self writeDefaults];	// need to save changes caused by key presses
    [super stopAnimation];
}

- (BOOL) hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
	[NSBundle loadNibNamed:@"Flurry.nib" owner:self];
	
	if (randomisePreset)
	{
		[randomPresetCheckbox setState:NSOnState];
		[randomDisplayCheckbox setEnabled:YES];
	}
	else
	{
		[randomPresetCheckbox setState:NSOffState];
		[randomDisplayCheckbox setEnabled:NO];
	}
	
	[randomDisplayCheckbox setState:randomiseDisplay ? NSOnState : NSOffState];
	
	[[presetManager popupButton] setFrame:[presetMenuSpace frame]];
	
	[[[flurryTable window] contentView] replaceSubview:presetMenuSpace with:[presetManager popupButton]];
	
	[flurryTable setDataSource:self];
	[flurryTable setDelegate:self];
	
	[[flurryTable delegate] tableViewSelectionDidChange:NULL];
	
	{
		int i;
		NSButtonCell *checkBox = [[NSButtonCell alloc] init];
		[checkBox setButtonType:NSSwitchButton];
		[checkBox setTitle:@""];
		for (i=0;i<[[NSScreen screens] count];i++)
		{
			NSString *n = [[NSNumber numberWithInt:(i + 1)] stringValue];
			NSTableColumn *tc = [[NSTableColumn alloc] initWithIdentifier:n];
			MonitorCell *monitorCell = [[MonitorCell alloc] initWithIndex:i];
			[tc setWidth:30];
			[tc setDataCell:checkBox];
			[tc setHeaderCell:monitorCell];
			[tc setResizingMask:NSTableColumnNoResizing];
			[tc setEditable:YES];
			[flurryTable addTableColumn:tc];
		}
	}
	
	[[flurryTable tableColumnWithIdentifier:@"colour"] setDataCell:[[ColourCell alloc] init]];
	
	[flurryTable sizeLastColumnToFit];
	
	tableRefreshTimer = [[NSTimer scheduledTimerWithTimeInterval:COLOUR_REFRESH_INTERVAL 
							target:self
							selector:@selector(refreshColours:)
							userInfo:NULL repeats:YES] retain];
	
    return window;
}

- (void)refreshColours:(NSTimer *)timer
{
	[[NSNotificationCenter defaultCenter] postNotificationName:UPDATE_COLOUR_NOTIF object:NULL];
	[flurryTable setNeedsDisplay:YES];
}

- (IBAction)displayReadMe:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:
		[[NSBundle bundleForClass:[FlurryView class]] pathForResource:@"readme" ofType:@"rtfd"]];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	return [presetManager handleEvent:theEvent];
}

- (void)selectedPresetDidChange
{
	if (flurryTable)
	{
		[flurryTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		[self tableViewSelectionDidChange:NULL];
	}
	[self stopAnimation];
	[self startAnimation];
}

- (IBAction)somethingChanged:(id)sender
{
	int i;
	for (i=0;i<[[[presetManager currentPreset] flurries] count];i++)
	{
		if ([flurryTable isRowSelected:i])
		{
			info = [[[[presetManager currentPreset] flurries] objectAtIndex:i] info];
			if (sender == colourMenu || sender == NULL)
			{
				info->currentColorMode = (ColorModes)[colourMenu indexOfSelectedItem];
			}
			else if (sender == streamCountSlider || sender == NULL)
				info->numStreams = [streamCountSlider intValue];
			else if (sender == speedSlider || sender == NULL)
				info->star->rotSpeed = [speedSlider floatValue];
			else if (sender == thicknessSlider || sender == NULL)
			{
				info->streamExpansion = [thicknessSlider floatValue];
				info->streamExpansion *= info->streamExpansion;
			}
		}
	}
	
	randomisePreset = [randomPresetCheckbox state] == NSOnState;
	if (!randomisePreset)
		[presetManager setViewPresetToCurrent];
	[randomDisplayCheckbox setEnabled:randomisePreset];
	randomiseDisplay = [randomDisplayCheckbox state] == NSOnState;
	
	[flurryTable reloadData];
}

- (IBAction)addFlurry:(id)sender
{
	int i;
	BOOL added = NO;
	NSMutableArray *newFlurries = [[NSMutableArray alloc] init];
	
	for (i=0;i<[[[presetManager currentPreset] flurries] count];i++)
	{
		if ([flurryTable isRowSelected:i])
		{
			added = YES;
			[newFlurries addObject:[[[[presetManager currentPreset] flurries] objectAtIndex:i] copy]];
		}
	}
	
	if (!added)
		[newFlurries addObject:[FlurryPreset classicFlurryPreset]];
	
	for (i=0;i<[newFlurries count];i++)
		[[presetManager currentPreset] addFlurry:[newFlurries objectAtIndex:i]];
	
	[newFlurries release];
	
	[flurryTable reloadData];
}

- (IBAction)deleteFlurry:(id)sender
{
	if ([flurryTable numberOfSelectedRows] < [[[presetManager currentPreset] flurries] count])
	{
		int i;
		NSMutableArray *toDelete = [[NSMutableArray alloc] init];
		
		for (i=0;i<[[[presetManager currentPreset] flurries] count];i++)
		{
			if ([flurryTable isRowSelected:i])
			{
				[toDelete addObject:[[[presetManager currentPreset] flurries] objectAtIndex:i]];
			}
		}
		
		for (i=0;i<[toDelete count];i++)
			[[presetManager currentPreset] deleteFlurry:[toDelete objectAtIndex:i]];
		
		[toDelete release];
		
		[flurryTable reloadData];
		[[flurryTable delegate] tableViewSelectionDidChange:NULL];
	}
	else
		NSBeep();
}

- (void)writeDefaults
{
	NSUserDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"Flurry"];
	
	[defaults setBool:randomisePreset forKey:RANDOM_PRESET_KEY];
	[defaults setBool:randomiseDisplay forKey:RANDOM_DISPLAY_KEY];
	
	[defaults synchronize];
	
	[presetManager writeDefaults];	// must do this afterwards in case we overwrite
}

- (IBAction)testNow:(id)sender
{
	NSUserDefaults *defaults;
	
	[presetManager setViewPresetToCurrent];
	[self writeDefaults];
	
	defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"Flurry"];	
	
	[defaults setBool:NO forKey:RANDOM_PRESET_KEY];
	[defaults setBool:NO forKey:RANDOM_DISPLAY_KEY];
	
	[defaults synchronize];
	
	[[NSWorkspace sharedWorkspace] launchApplication:@"ScreenSaverEngine"];
}

- (IBAction)saveAndCloseSheet:(id)sender
{
	[[self window] makeFirstResponder:nil];
	[tableRefreshTimer invalidate];
	[tableRefreshTimer release];
	[self writeDefaults];
	[NSApp endSheet:window];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [[[presetManager currentPreset] flurries] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	Flurry *flurry;
	int screenIndex;
	
	NSParameterAssert(row >= 0 && row < [[[presetManager currentPreset] flurries] count]);
	
	flurry = [[[presetManager currentPreset] flurries] objectAtIndex:row];
	
	if (screenIndex = [[tableColumn identifier] intValue])
	{
		return [NSNumber numberWithBool:[flurry shouldDrawOnScreenIndex:(screenIndex - 1) randomise:FALSE]];
	}
	else
		return [flurry valueForKey:[tableColumn identifier]];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	Flurry *flurry;
	int screenIndex;
	
	NSParameterAssert(row >= 0 && row < [[[presetManager currentPreset] flurries] count]);
	
	flurry = [[[presetManager currentPreset] flurries] objectAtIndex:row];
	
	if (screenIndex = [[tableColumn identifier] intValue])
	{
		[flurry setDraws:[object boolValue] onScreen:(screenIndex - 1)];
	}
	else
		[flurry takeValue:object forKey:[tableColumn identifier]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	int selection = [flurryTable selectedRow];
	
	NSParameterAssert(selection >= 0 && selection < [[[presetManager currentPreset] flurries] count]);
	
	if ([flurryTable numberOfSelectedRows])
	{
		Flurry *flurry = [[[presetManager currentPreset] flurries] objectAtIndex:selection];
		
		info = [flurry info];
		
		[colourMenu selectItemAtIndex:info->currentColorMode];
		[streamCountSlider setIntValue:info->numStreams];
		[thicknessSlider setFloatValue:sqrt(info->streamExpansion)];
		[speedSlider setFloatValue:info->star->rotSpeed];
	}
}

@end

@implementation MonitorCell

- (void)dealloc
{
	[index release];
	[super dealloc];
}

- (id)initWithIndex:(NSString *)newIndex
{
	NSString *path = [[NSBundle bundleForClass:[FlurryView class]] pathForImageResource:@"displays"];
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
	
	if (self = [super initImageCell:image])
	{
		index = [newIndex retain];
	}
	[image release];
	return self;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSPoint point = cellFrame.origin;
	point.x += 13;
	point.y += 4;
	[super drawInteriorWithFrame:NSOffsetRect(cellFrame, 0, 1) inView:controlView];
	[index drawAtPoint:point withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSColor whiteColor], NSForegroundColorAttributeName, 
			[NSFont systemFontOfSize:8], NSFontAttributeName, NULL]];
}

@end
