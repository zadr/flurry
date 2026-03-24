// Spark.cpp: implementation of the Spark class.
//
//////////////////////////////////////////////////////////////////////

#include "Std.h"
#include "Spark.h"
#include "MatrixUtils.h"

__private_extern__ void InitSpark(Spark *s)
{
	int i;
	for (i=0;i<3;i++)
	{
		s->position[i] = RandFlt(-100.0, 100.0);
	}
}

// Convert a GL_QUAD_STRIP of 6 vertices into 4 triangles (12 triangle vertices).
static int EmitQuadStrip6(float *outV, float *outC, int offset,
                          float vx[6], float vy[6],
                          float cr[6], float cg[6], float cb[6], float ca[6])
{
    int tri[12] = {0,1,2, 2,1,3, 2,3,4, 4,3,5};
    int i;
    for (i = 0; i < 12; i++) {
        int idx = tri[i];
        int o = offset + i;
        outV[o*2+0] = vx[idx];
        outV[o*2+1] = vy[idx];
        outC[o*4+0] = cr[idx];
        outC[o*4+1] = cg[idx];
        outC[o*4+2] = cb[idx];
        outC[o*4+3] = ca[idx];
    }
    return 12;
}

__private_extern__ int DrawSpark(Spark *s, float *outVertices, float *outColors)
{
	float width,sx,sy;
	float a;
	float c = 0.0625f;
	float screenx;
	float screeny;
	float w,z, scale;
	int k;
	int totalVerts = 0;

	width = 60000.0f * info->sys_glWidth / 1024.0f;

	z = s->position[2];
	sx = s->position[0] * info->sys_glWidth / z + info->sys_glWidth * 0.5f;
	sy = s->position[1] * info->sys_glWidth / z + info->sys_glHeight * 0.5f;
	w = width*4.0f / z;

	screenx = sx;
	screeny = sy;
	scale = w/50.0f;

	simd_float4x4 modelMatrix = simd_mul(matrix_translate(screenx, screeny), matrix_scale(scale, scale));

	for (k=0;k<12;k++)
	{
		a = ((float) (rand() % 3600)) / 10.0f;
		float aRad = a * (PI / 180.0f);
		modelMatrix = simd_mul(modelMatrix, matrix_rotate_z(aRad));

		float lx[6], ly[6];
		float cr[6], cg[6], cb[6], ca[6];

		float stripLen = 2.0f + (float) (rand() & 255) * c;

		// Vertex 0: black, (-3, 0)
		lx[0] = -3.0f; ly[0] = 0.0f;
		cr[0] = 0.0f; cg[0] = 0.0f; cb[0] = 0.0f; ca[0] = 1.0f;
		// Vertex 1: black, (-3, stripLen)
		lx[1] = -3.0f; ly[1] = stripLen;
		cr[1] = 0.0f; cg[1] = 0.0f; cb[1] = 0.0f; ca[1] = 1.0f;
		// Vertex 2: spark color, (0, 0)
		lx[2] = 0.0f; ly[2] = 0.0f;
		cr[2] = s->color[0]; cg[2] = s->color[1]; cb[2] = s->color[2]; ca[2] = s->color[3];
		// Vertex 3: black, (0, stripLen)
		lx[3] = 0.0f; ly[3] = stripLen;
		cr[3] = 0.0f; cg[3] = 0.0f; cb[3] = 0.0f; ca[3] = 1.0f;
		// Vertex 4: black, (3, 0)
		lx[4] = 3.0f; ly[4] = 0.0f;
		cr[4] = 0.0f; cg[4] = 0.0f; cb[4] = 0.0f; ca[4] = 1.0f;
		// Vertex 5: black, (3, stripLen)
		lx[5] = 3.0f; ly[5] = stripLen;
		cr[5] = 0.0f; cg[5] = 0.0f; cb[5] = 0.0f; ca[5] = 1.0f;

		float vx[6], vy[6];
		int v;
		for (v = 0; v < 6; v++) {
			simd_float2 transformed = matrix_transform_point(modelMatrix, lx[v], ly[v]);
			vx[v] = transformed.x;
			vy[v] = transformed.y;
		}

		totalVerts += EmitQuadStrip6(outVertices, outColors, totalVerts,
		                             vx, vy, cr, cg, cb, ca);
	}
	return totalVerts;
}

#define BIGMYSTERY 1800.0
#define MAXANGLES 16384

__private_extern__ void UpdateSparkColour(Spark *s)
{
	const float rotationsPerSecond = (float) (2.0*PI*fieldSpeed/MAXANGLES);
	double thisPointInRadians;
	double thisAngle = info->fTime*rotationsPerSecond;
	float cf;
	float cycleTime = 20.0f;
	float colorRot;
	float redPhaseShift;
	float greenPhaseShift; 
	float bluePhaseShift;
	float baseRed;
	float baseGreen;
	float baseBlue;
	float colorTime;
	
	if (info->currentColorMode == rainbowColorMode)
	{
		cycleTime = 1.5f;
	}
	else if (info->currentColorMode == tiedyeColorMode)
	{
		cycleTime = 4.5f;
	}
	else if (info->currentColorMode == cyclicColorMode)
	{
		cycleTime = 20.0f;
	}
	else if (info->currentColorMode == slowCyclicColorMode)
	{
		cycleTime = 120.0f;
	}
	colorRot = (float) (2.0*PI/cycleTime);
	redPhaseShift = 0.0f; //cycleTime * 0.0f / 3.0f 
	greenPhaseShift = cycleTime / 3.0f; 
	bluePhaseShift = cycleTime * 2.0f / 3.0f ;
	colorTime = info->fTime;
	if (info->currentColorMode == whiteColorMode)
	{
		baseRed = 0.1875f;
		baseGreen = 0.1875f;
		baseBlue = 0.1875f;
	}
	else if (info->currentColorMode == multiColorMode)
	{
		baseRed = 0.0625f;
		baseGreen = 0.0625f;
		baseBlue = 0.0625f;
	}
	else if (info->currentColorMode == darkColorMode)
	{
		baseRed = 0.0f;
		baseGreen = 0.0f;
		baseBlue = 0.0f;
	}
	else
	{
		if (info->currentColorMode < slowCyclicColorMode)
		{
			colorTime = (info->currentColorMode / 6.0f) * cycleTime;
		}
		else
		{
			colorTime = info->fTime + info->flurryRandomSeed;
		}
		baseRed = 0.109375f * ((float) cos((colorTime+redPhaseShift)*colorRot)+1.0f);
		baseGreen = 0.109375f * ((float) cos((colorTime+greenPhaseShift)*colorRot)+1.0f);
		baseBlue = 0.109375f * ((float) cos((colorTime+bluePhaseShift)*colorRot)+1.0f);
	}
	
	cf = ((float) (cos(7.0*((info->fTime)*rotationsPerSecond))+cos(3.0*((info->fTime)*rotationsPerSecond))+cos(13.0*((info->fTime)*rotationsPerSecond))));
	cf /= 6.0f;
	cf += 2.0f;
	thisPointInRadians = 2.0 * PI * (double) s->mystery / (double) BIGMYSTERY;
	
	s->color[0] = baseRed + 0.0625f * (0.5f + (float) cos((15.0 * (thisPointInRadians + 3.0*thisAngle))) + (float) sin((7.0 * (thisPointInRadians + thisAngle))));
	s->color[1] = baseGreen + 0.0625f * (0.5f + (float) sin(((thisPointInRadians) + thisAngle)));
	s->color[2] = baseBlue + 0.0625f * (0.5f + (float) cos((37.0 * (thisPointInRadians + thisAngle))));
}

__private_extern__ void UpdateSpark(Spark *s)
{
    const float rotationsPerSecond = (float) (2.0*PI*fieldSpeed/MAXANGLES);
    double thisPointInRadians;
    double thisAngle = info->fTime*rotationsPerSecond;
    float cf;
    int i;
    double tmpX1,tmpY1,tmpZ1;
    double tmpX2,tmpY2,tmpZ2;
    double tmpX3,tmpY3,tmpZ3;
    double tmpX4,tmpY4,tmpZ4;
    double rotation;
    double cr;
    double sr;
    float cycleTime = 20.0f;
    float colorRot;
    float redPhaseShift;
    float greenPhaseShift; 
    float bluePhaseShift;
    float baseRed;
    float baseGreen;
    float baseBlue;
    float colorTime;
    
    float old[3];
    
    if (info->currentColorMode == rainbowColorMode) {
        cycleTime = 1.5f;
    } else if (info->currentColorMode == tiedyeColorMode) {
        cycleTime = 4.5f;
    } else if (info->currentColorMode == cyclicColorMode) {
        cycleTime = 20.0f;
    } else if (info->currentColorMode == slowCyclicColorMode) {
        cycleTime = 120.0f;
    }
    colorRot = (float) (2.0*PI/cycleTime);
    redPhaseShift = 0.0f; //cycleTime * 0.0f / 3.0f 
    greenPhaseShift = cycleTime / 3.0f; 
    bluePhaseShift = cycleTime * 2.0f / 3.0f ;
    colorTime = info->fTime;
    if (info->currentColorMode == whiteColorMode) {
        baseRed = 0.1875f;
        baseGreen = 0.1875f;
        baseBlue = 0.1875f;
    } else if (info->currentColorMode == multiColorMode) {
        baseRed = 0.0625f;
        baseGreen = 0.0625f;
        baseBlue = 0.0625f;
    } else if (info->currentColorMode == darkColorMode) {
        baseRed = 0.0f;
        baseGreen = 0.0f;
        baseBlue = 0.0f;
    } else {
        if(info->currentColorMode < slowCyclicColorMode) {
            colorTime = (info->currentColorMode / 6.0f) * cycleTime;
        } else {
            colorTime = info->fTime + info->flurryRandomSeed;
        }
        baseRed = 0.109375f * ((float) cos((colorTime+redPhaseShift)*colorRot)+1.0f);
        baseGreen = 0.109375f * ((float) cos((colorTime+greenPhaseShift)*colorRot)+1.0f);
        baseBlue = 0.109375f * ((float) cos((colorTime+bluePhaseShift)*colorRot)+1.0f);
    }
    
    for (i=0;i<3;i++) {
        old[i] = s->position[i];
    }
    
    cf = ((float) (cos(7.0*((info->fTime)*rotationsPerSecond))+cos(3.0*((info->fTime)*rotationsPerSecond))+cos(13.0*((info->fTime)*rotationsPerSecond))));
    cf /= 6.0f;
    cf += 2.0f;
    thisPointInRadians = 2.0 * PI * (double) s->mystery / (double) BIGMYSTERY;
    
    s->color[0] = baseRed + 0.0625f * (0.5f + (float) cos((15.0 * (thisPointInRadians + 3.0*thisAngle))) + (float) sin((7.0 * (thisPointInRadians + thisAngle))));
    s->color[1] = baseGreen + 0.0625f * (0.5f + (float) sin(((thisPointInRadians) + thisAngle)));
    s->color[2] = baseBlue + 0.0625f * (0.5f + (float) cos((37.0 * (thisPointInRadians + thisAngle))));
    s->position[0] = fieldRange * cf * (float) cos(11.0 * (thisPointInRadians + (3.0*thisAngle)));
    s->position[1] = fieldRange * cf * (float) sin(12.0 * (thisPointInRadians + (4.0*thisAngle)));
    s->position[2] = fieldRange * (float) cos((23.0 * (thisPointInRadians + (12.0*thisAngle))));
    
    rotation = thisAngle*0.501 + 5.01 * (double) s->mystery / (double) BIGMYSTERY;
    cr = cos(rotation);
    sr = sin(rotation);
    tmpX1 = s->position[0] * cr - s->position[1] * sr;
    tmpY1 = s->position[1] * cr + s->position[0] * sr;
    tmpZ1 = s->position[2];
    
    tmpX2 = tmpX1 * cr - tmpZ1 * sr;
    tmpY2 = tmpY1;
    tmpZ2 = tmpZ1 * cr + tmpX1 * sr;
    
    tmpX3 = tmpX2;
    tmpY3 = tmpY2 * cr - tmpZ2 * sr;
    tmpZ3 = tmpZ2 * cr + tmpY2 * sr + seraphDistance;
    
    rotation = thisAngle*2.501 + 85.01 * (double) s->mystery / (double) BIGMYSTERY;
    cr = cos(rotation);
    sr = sin(rotation);
    tmpX4 = tmpX3 * cr - tmpY3 * sr;
    tmpY4 = tmpY3 * cr + tmpX3 * sr;
    tmpZ4 = tmpZ3;
    
    s->position[0] = (float) tmpX4 + RandBell(5.0f*fieldCoherence);
    s->position[1] = (float) tmpY4 + RandBell(5.0f*fieldCoherence);
    s->position[2] = (float) tmpZ4 + RandBell(5.0f*fieldCoherence);

    for (i=0;i<3;i++) {
        s->delta[i] = (s->position[i] - old[i])/info->fDeltaTime;
    }
}
