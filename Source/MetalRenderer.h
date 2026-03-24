#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetalRenderer : NSObject

- (nullable instancetype)initWithLayer:(CAMetalLayer *)layer;
- (void)resize:(CGSize)size;

- (void)beginFrameWithClear:(BOOL)clear;
- (void)drawDimmingQuadWithAlpha:(float)alpha;
- (void)drawSmokeWithVertices:(const float *)vertices
                       colors:(const float *)colors
                    texCoords:(const float *)texCoords
                    quadCount:(int)count;
- (void)drawUntexturedTriangles:(const float *)vertices
                         colors:(const float *)colors
                    vertexCount:(int)count;
- (void)endFrame;

- (void)createParticleTextureFromData:(const unsigned char *)data
                                width:(int)width
                               height:(int)height;

@end

NS_ASSUME_NONNULL_END
