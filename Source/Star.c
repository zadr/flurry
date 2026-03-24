// Star.c: implementation of the Star class.
//
//////////////////////////////////////////////////////////////////////

#include "Std.h"
#include "Star.h"
#include "MatrixUtils.h"

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

__private_extern__ void InitStar(Star *s)
{
    int i;
    for (i=0;i<3;i++) {
        s->position[i] = RandFlt(-10000.0, 10000.0);
    }
    s->rotSpeed = RandFlt(0.4, 0.9);
    s->mystery = RandFlt(0.0, 10.0);
}

// Convert a GL_QUAD_STRIP of 6 vertices into 4 triangles (12 triangle vertices).
// Strip order: 0,1,2,3,4,5 -> triangles (0,1,2), (2,1,3), (2,3,4), (4,3,5)
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

__private_extern__ int DrawStar(Star *s, float *outVertices, float *outColors)
{
    float width,sx,sy;
    float w,z;
    float screenx;
    float screeny;
    float scale;
    float a;
    float c = 0.08f;
    float r,g,b;
    int k;
    int totalVerts = 0;

    if(s->ate == false) {
        return 0;
    }

    width = 50000.0f * info->sys_glWidth / 1024.0f;

    z = s->position[2];
    sx = s->position[0] * info->sys_glWidth / z + info->sys_glWidth * 0.5f;
    sy = s->position[1] * info->sys_glWidth / z + info->sys_glHeight * 0.5f;
    w = width*4.0f / z;

    screenx = sx;
    screeny = sy;
    scale = w/100.0f;

    // Build model matrix: translate then scale
    simd_float4x4 modelMatrix = simd_mul(matrix_translate(screenx, screeny), matrix_scale(scale, scale));

    for (k=0;k<30;k++) {
        a = ((float) (rand() % 3600)) / 10.0f;
        float aRad = a * (PI / 180.0f);
        modelMatrix = simd_mul(modelMatrix, matrix_rotate_z(aRad));

        // 6 strip vertices in local space
        float lx[6], ly[6];
        float cr[6], cg[6], cb[6], ca[6];

        float stripLen = 3.0f + (float) (rand() & 2047) * c;
        r = 0.125f + (float) (rand() % 875) / 1000.0f;
        g = 0.125f + (float) (rand() % 875) / 1000.0f;
        b = 0.125f + (float) (rand() % 875) / 1000.0f;

        // Vertex 0: black, (-3, 0)
        lx[0] = -3.0f; ly[0] = 0.0f;
        cr[0] = 0.0f; cg[0] = 0.0f; cb[0] = 0.0f; ca[0] = 1.0f;
        // Vertex 1: black, (-3, stripLen)
        lx[1] = -3.0f; ly[1] = stripLen;
        cr[1] = 0.0f; cg[1] = 0.0f; cb[1] = 0.0f; ca[1] = 1.0f;
        // Vertex 2: colored, (0, 0)
        lx[2] = 0.0f; ly[2] = 0.0f;
        cr[2] = r; cg[2] = g; cb[2] = b; ca[2] = 1.0f;
        // Vertex 3: black, (0, stripLen)
        lx[3] = 0.0f; ly[3] = stripLen;
        cr[3] = 0.0f; cg[3] = 0.0f; cb[3] = 0.0f; ca[3] = 1.0f;
        // Vertex 4: black, (3, 0)
        lx[4] = 3.0f; ly[4] = 0.0f;
        cr[4] = 0.0f; cg[4] = 0.0f; cb[4] = 0.0f; ca[4] = 1.0f;
        // Vertex 5: black, (3, stripLen)
        lx[5] = 3.0f; ly[5] = stripLen;
        cr[5] = 0.0f; cg[5] = 0.0f; cb[5] = 0.0f; ca[5] = 1.0f;

        // Transform all 6 vertices by modelMatrix
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

__private_extern__ void UpdateStar(Star *s)
{
    float rotationsPerSecond = (float) (2.0*PI*12.0/MAXANGLES) * s->rotSpeed /* speed control */;
    double thisPointInRadians;
    double thisAngle = info->fTime*rotationsPerSecond;
    float cf;
    double tmpX1,tmpY1,tmpZ1;
    double tmpX2,tmpY2,tmpZ2;
    double tmpX3,tmpY3,tmpZ3;
    double tmpX4,tmpY4,tmpZ4;
    double rotation;
    double cr;
    double sr;

    s->ate = false;
    
    cf = ((float) (cos(7.0*((info->fTime)*rotationsPerSecond))+cos(3.0*((info->fTime)*rotationsPerSecond))+cos(13.0*((info->fTime)*rotationsPerSecond))));
    cf /= 6.0f;
    cf += 0.75f; 
    thisPointInRadians = 2.0 * PI * (double) s->mystery / (double) BIGMYSTERY;
    
    s->position[0] = 250.0f * cf * (float) cos(11.0 * (thisPointInRadians + (3.0*thisAngle)));
    s->position[1] = 250.0f * cf * (float) sin(12.0 * (thisPointInRadians + (4.0*thisAngle)));
    s->position[2] = 250.0f * (float) cos((23.0 * (thisPointInRadians + (12.0*thisAngle))));
    
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
    
    s->position[0] = (float) tmpX4;
    s->position[1] = (float) tmpY4;
    s->position[2] = (float) tmpZ4;
}
