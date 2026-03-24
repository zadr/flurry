#ifndef MATRIXUTILS_H
#define MATRIXUTILS_H

#include <simd/simd.h>

static inline simd_float4x4 matrix_ortho2d(float left, float right, float bottom, float top) {
    float rl = right - left;
    float tb = top - bottom;
    simd_float4x4 m = {
        .columns[0] = { 2.0f / rl, 0, 0, 0 },
        .columns[1] = { 0, 2.0f / tb, 0, 0 },
        .columns[2] = { 0, 0, -1.0f, 0 },
        .columns[3] = { -(right + left) / rl, -(top + bottom) / tb, 0, 1.0f }
    };
    return m;
}

static inline simd_float4x4 matrix_translate(float tx, float ty) {
    simd_float4x4 m = matrix_identity_float4x4;
    m.columns[3].x = tx;
    m.columns[3].y = ty;
    return m;
}

static inline simd_float4x4 matrix_scale(float sx, float sy) {
    simd_float4x4 m = matrix_identity_float4x4;
    m.columns[0].x = sx;
    m.columns[1].y = sy;
    return m;
}

static inline simd_float4x4 matrix_rotate_z(float radians) {
    float c = cosf(radians);
    float s = sinf(radians);
    simd_float4x4 m = matrix_identity_float4x4;
    m.columns[0].x = c;
    m.columns[0].y = s;
    m.columns[1].x = -s;
    m.columns[1].y = c;
    return m;
}

static inline simd_float2 matrix_transform_point(simd_float4x4 m, float x, float y) {
    simd_float4 p = { x, y, 0, 1 };
    simd_float4 r = simd_mul(m, p);
    return (simd_float2){ r.x, r.y };
}

#endif
