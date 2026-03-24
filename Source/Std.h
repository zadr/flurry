//-------------------------------------------------------------------
//  File:   Std.h
//  Created:  02/12/00 9:01:PM
//  Author:   Aaron Hilton
//  Comments: Standard header file to include all source files.
//            (Precompiled header)
//-------------------------------------------------------------------
#ifndef __STD_h_
#define __STD_h_

#include <stdlib.h>
#include <stdbool.h>
#include <math.h>

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#include "PTypes.h"
#include "Gl_saver.h"

__private_extern__ float FastDistance2D(float x, float y);

#define RandFlt(min, max) (min + (max - min) * rand() / (float) RAND_MAX)

#define RandBell(scale) (scale * (1.0f - (rand() + rand() + rand()) / ((float) RAND_MAX * 1.5f)))

#endif // _STD_h_
