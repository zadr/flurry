#import "MetalRenderer.h"
#import "MatrixUtils.h"
#import "Smoke.h"
#include <dispatch/dispatch.h>

typedef struct {
    simd_float4x4 projectionMatrix;
} Uniforms;

typedef struct {
    simd_float2 position;
    simd_float4 color;
    simd_float2 texCoord;
} VertexData;

#define kMaxBufferFrames 3
// Worst case: smoke (3600 quads * 6 verts) + dimming (6 verts) + star/sparks (~2500 verts)
#define kMaxVerticesPerFrame (3600 * 6 + 6 + 3000)

@implementation MetalRenderer {
    CAMetalLayer *_layer;
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;

    id<MTLRenderPipelineState> _texturedAdditivePipeline;
    id<MTLRenderPipelineState> _untexturedAlphaBlendPipeline;
    id<MTLRenderPipelineState> _untexturedAdditivePipeline;

    id<MTLTexture> _particleTexture;
    id<MTLSamplerState> _sampler;

    id<MTLBuffer> _quadIndexBuffer;

    id<MTLBuffer> _vertexBuffers[kMaxBufferFrames];
    int _currentBufferIndex;
    dispatch_semaphore_t _frameSemaphore;

    id<MTLRenderCommandEncoder> _encoder;
    id<MTLCommandBuffer> _commandBuffer;
    id<CAMetalDrawable> _currentDrawable;

    Uniforms _uniforms;
    id<MTLBuffer> _uniformBuffer;
    CGSize _viewportSize;
    int _vertexOffset;
}

- (nullable instancetype)initWithLayer:(CAMetalLayer *)layer {
    if (self = [super init]) {
        _layer = layer;
        _device = MTLCreateSystemDefaultDevice();
        if (!_device) return nil;

        _layer.device = _device;
        _layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        _layer.framebufferOnly = NO;

        _commandQueue = [_device newCommandQueue];
        _library = [_device newDefaultLibrary];

        [self _createPipelineStates];
        [self _createSampler];
        [self _createQuadIndexBuffer];
        [self _createVertexBuffers];

        _uniformBuffer = [_device newBufferWithLength:sizeof(Uniforms) options:MTLResourceStorageModeShared];

        _frameSemaphore = dispatch_semaphore_create(kMaxBufferFrames);
        _currentBufferIndex = 0;
    }
    return self;
}

- (void)_createPipelineStates {
    id<MTLFunction> vertTextured = [_library newFunctionWithName:@"vertex_textured"];
    id<MTLFunction> fragTextured = [_library newFunctionWithName:@"fragment_textured"];
    id<MTLFunction> vertUntextured = [_library newFunctionWithName:@"vertex_untextured"];
    id<MTLFunction> fragUntextured = [_library newFunctionWithName:@"fragment_untextured"];

    // Pipeline 1: Textured + Additive
    {
        MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
        desc.vertexFunction = vertTextured;
        desc.fragmentFunction = fragTextured;
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.colorAttachments[0].blendingEnabled = YES;
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
        desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
        NSError *err = nil;
        _texturedAdditivePipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&err];
    }

    // Pipeline 2: Untextured + Alpha Blend
    {
        MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
        desc.vertexFunction = vertUntextured;
        desc.fragmentFunction = fragUntextured;
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.colorAttachments[0].blendingEnabled = YES;
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        NSError *err = nil;
        _untexturedAlphaBlendPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&err];
    }

    // Pipeline 3: Untextured + Additive
    {
        MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
        desc.vertexFunction = vertUntextured;
        desc.fragmentFunction = fragUntextured;
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.colorAttachments[0].blendingEnabled = YES;
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
        desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
        NSError *err = nil;
        _untexturedAdditivePipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&err];
    }
}

- (void)_createSampler {
    MTLSamplerDescriptor *desc = [[MTLSamplerDescriptor alloc] init];
    desc.minFilter = MTLSamplerMinMagFilterLinear;
    desc.magFilter = MTLSamplerMinMagFilterLinear;
    desc.mipFilter = MTLSamplerMipFilterLinear;
    desc.sAddressMode = MTLSamplerAddressModeRepeat;
    desc.tAddressMode = MTLSamplerAddressModeRepeat;
    _sampler = [_device newSamplerStateWithDescriptor:desc];
}

- (void)_createQuadIndexBuffer {
    // Pre-build index buffer for NUMSMOKEPARTICLES quads → triangle pairs
    uint16_t *indices = malloc(NUMSMOKEPARTICLES * 6 * sizeof(uint16_t));
    for (int i = 0; i < NUMSMOKEPARTICLES; i++) {
        int base = i * 4;
        int idx = i * 6;
        indices[idx + 0] = base + 0;
        indices[idx + 1] = base + 1;
        indices[idx + 2] = base + 2;
        indices[idx + 3] = base + 0;
        indices[idx + 4] = base + 2;
        indices[idx + 5] = base + 3;
    }
    _quadIndexBuffer = [_device newBufferWithBytes:indices
                                            length:NUMSMOKEPARTICLES * 6 * sizeof(uint16_t)
                                           options:MTLResourceStorageModeShared];
    free(indices);
}

- (void)_createVertexBuffers {
    NSUInteger size = kMaxVerticesPerFrame * sizeof(VertexData);
    for (int i = 0; i < kMaxBufferFrames; i++) {
        _vertexBuffers[i] = [_device newBufferWithLength:size options:MTLResourceStorageModeShared];
    }
}

- (void)resize:(CGSize)size {
    _viewportSize = size;
    _layer.drawableSize = size;
    // OpenGL-style ortho: Y-up (0 at bottom, height at top)
    _uniforms.projectionMatrix = matrix_ortho2d(0, size.width, 0, size.height);
    memcpy(_uniformBuffer.contents, &_uniforms, sizeof(Uniforms));
}

- (void)beginFrameWithClear:(BOOL)clear {
    dispatch_semaphore_wait(_frameSemaphore, DISPATCH_TIME_FOREVER);

    _currentDrawable = [_layer nextDrawable];
    if (!_currentDrawable) {
        dispatch_semaphore_signal(_frameSemaphore);
        return;
    }

    _vertexOffset = 0;
    _commandBuffer = [_commandQueue commandBuffer];

    MTLRenderPassDescriptor *passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    passDesc.colorAttachments[0].texture = _currentDrawable.texture;
    passDesc.colorAttachments[0].loadAction = clear ? MTLLoadActionClear : MTLLoadActionLoad;
    passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

    _encoder = [_commandBuffer renderCommandEncoderWithDescriptor:passDesc];
    [_encoder setViewport:(MTLViewport){0, 0, _viewportSize.width, _viewportSize.height, 0, 1}];
}

- (void)drawDimmingQuadWithAlpha:(float)alpha {
    if (!_encoder) return;

    [_encoder setRenderPipelineState:_untexturedAlphaBlendPipeline];

    float w = _viewportSize.width;
    float h = _viewportSize.height;

    VertexData *verts = (VertexData *)_vertexBuffers[_currentBufferIndex].contents + _vertexOffset;
    simd_float4 col = { 0, 0, 0, alpha };
    simd_float2 tc = { 0, 0 };

    // Two triangles for full-screen quad
    verts[0] = (VertexData){ {0, 0}, col, tc };
    verts[1] = (VertexData){ {w, 0}, col, tc };
    verts[2] = (VertexData){ {w, h}, col, tc };
    verts[3] = (VertexData){ {0, 0}, col, tc };
    verts[4] = (VertexData){ {w, h}, col, tc };
    verts[5] = (VertexData){ {0, h}, col, tc };

    [_encoder setVertexBuffer:_vertexBuffers[_currentBufferIndex]
                       offset:_vertexOffset * sizeof(VertexData)
                      atIndex:0];
    [_encoder setVertexBuffer:_uniformBuffer offset:0 atIndex:1];
    [_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

    _vertexOffset += 6;
}

- (void)drawSmokeWithVertices:(const float *)vertices
                       colors:(const float *)colors
                    texCoords:(const float *)texCoords
                    quadCount:(int)count {
    if (!_encoder || count <= 0) return;

    [_encoder setRenderPipelineState:_texturedAdditivePipeline];

    int vertCount = count * 4;
    VertexData *verts = (VertexData *)_vertexBuffers[_currentBufferIndex].contents + _vertexOffset;

    // Interleave SOA → AOS
    // vertices: pairs of float2 packed as floatToVector (4 floats per floatToVector, 2 per quad side)
    // The smoke vertex data is stored as:
    //   seraphimVertices: array of floatToVector, each containing 2 float2 positions (4 floats)
    //   seraphimColors: array of floatToVector, each containing 4 color floats (RGBA for one vertex)
    //   seraphimTextures: flat array of float pairs (u,v) per vertex
    for (int q = 0; q < count; q++) {
        // Each quad has 4 vertices
        // Vertices are packed: 2 floatToVectors per quad (each holds 2 vertices as x,y pairs)
        int vbase = q * 2; // index into floatToVector array
        int tbase = q * 8; // 4 verts * 2 floats each
        int cbase = q * 4; // 4 floatToVectors of color

        // Vertex 0: seraphimVertices[vbase].f[0,1]
        // Vertex 1: seraphimVertices[vbase].f[2,3]
        // Vertex 2: seraphimVertices[vbase+1].f[0,1]
        // Vertex 3: seraphimVertices[vbase+1].f[2,3]
        float v0x = vertices[vbase * 4 + 0];
        float v0y = vertices[vbase * 4 + 1];
        float v1x = vertices[vbase * 4 + 2];
        float v1y = vertices[vbase * 4 + 3];
        float v2x = vertices[(vbase + 1) * 4 + 0];
        float v2y = vertices[(vbase + 1) * 4 + 1];
        float v3x = vertices[(vbase + 1) * 4 + 2];
        float v3y = vertices[(vbase + 1) * 4 + 3];

        // Colors: seraphimColors[cbase+j] has .f[0..3] = RGBA for vertex j
        for (int v = 0; v < 4; v++) {
            int ci = (cbase + v) * 4;
            float px, py;
            switch (v) {
                case 0: px = v0x; py = v0y; break;
                case 1: px = v1x; py = v1y; break;
                case 2: px = v2x; py = v2y; break;
                case 3: px = v3x; py = v3y; break;
            }
            verts[q * 4 + v] = (VertexData){
                { px, py },
                { colors[ci], colors[ci + 1], colors[ci + 2], colors[ci + 3] },
                { texCoords[tbase + v * 2], texCoords[tbase + v * 2 + 1] }
            };
        }
    }

    [_encoder setVertexBuffer:_vertexBuffers[_currentBufferIndex]
                       offset:_vertexOffset * sizeof(VertexData)
                      atIndex:0];
    [_encoder setVertexBuffer:_uniformBuffer offset:0 atIndex:1];
    [_encoder setFragmentTexture:_particleTexture atIndex:0];
    [_encoder setFragmentSamplerState:_sampler atIndex:0];

    [_encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                         indexCount:count * 6
                          indexType:MTLIndexTypeUInt16
                        indexBuffer:_quadIndexBuffer
                  indexBufferOffset:0];

    _vertexOffset += vertCount;
}

- (void)drawUntexturedTriangles:(const float *)vertices
                         colors:(const float *)colors
                    vertexCount:(int)count {
    if (!_encoder || count <= 0) return;

    [_encoder setRenderPipelineState:_untexturedAdditivePipeline];

    VertexData *verts = (VertexData *)_vertexBuffers[_currentBufferIndex].contents + _vertexOffset;

    for (int i = 0; i < count; i++) {
        verts[i] = (VertexData){
            { vertices[i * 2], vertices[i * 2 + 1] },
            { colors[i * 4], colors[i * 4 + 1], colors[i * 4 + 2], colors[i * 4 + 3] },
            { 0, 0 }
        };
    }

    [_encoder setVertexBuffer:_vertexBuffers[_currentBufferIndex]
                       offset:_vertexOffset * sizeof(VertexData)
                      atIndex:0];
    [_encoder setVertexBuffer:_uniformBuffer offset:0 atIndex:1];
    [_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:count];

    _vertexOffset += count;
}

- (void)endFrame {
    if (!_encoder) return;

    [_encoder endEncoding];
    _encoder = nil;

    [_commandBuffer presentDrawable:_currentDrawable];

    __block dispatch_semaphore_t sem = _frameSemaphore;
    [_commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buf) {
        dispatch_semaphore_signal(sem);
    }];

    [_commandBuffer commit];
    _commandBuffer = nil;
    _currentDrawable = nil;
    _currentBufferIndex = (_currentBufferIndex + 1) % kMaxBufferFrames;
}

- (void)createParticleTextureFromData:(const unsigned char *)data
                                width:(int)width
                               height:(int)height {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG8Unorm
                                                                                    width:width
                                                                                   height:height
                                                                                mipmapped:YES];
    _particleTexture = [_device newTextureWithDescriptor:desc];

    [_particleTexture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                        mipmapLevel:0
                          withBytes:data
                        bytesPerRow:width * 2];

    // Generate mipmaps
    id<MTLCommandBuffer> cmdBuf = [_commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
    [blit generateMipmapsForTexture:_particleTexture];
    [blit endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];
}

@end
