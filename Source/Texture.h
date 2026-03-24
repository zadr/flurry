/*
 *  Texture.h
 *  AppleFlurry
 *
 *  Created by Mike Trent on Wed May 22 2002.
 *  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
 *
 */

#define PARTICLE_TEXTURE_WIDTH 256
#define PARTICLE_TEXTURE_HEIGHT 256

// GenerateParticleTextureData creates the procedural texture and returns
// a pointer to the static 256x256 RG (luminance+alpha) texture data.
__private_extern__ unsigned char *GenerateParticleTextureData(void);
