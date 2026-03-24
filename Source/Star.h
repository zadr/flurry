// Star.h: interface for the Star class.
//
//////////////////////////////////////////////////////////////////////

#if !defined(STAR_H)
#define STAR_H

typedef struct Star
{
	float position[3];
	bool ate;
	float mystery;
	float rotSpeed;
} Star;

__private_extern__ void UpdateStar(Star *s);
__private_extern__ int DrawStar(Star *s, float *outVertices, float *outColors);
__private_extern__ void InitStar(Star *s);

#endif // !defined(STAR_H)
