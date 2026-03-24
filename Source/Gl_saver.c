#include <stdbool.h>
#include <sys/time.h>

#include "Gl_saver.h"
#include "Std.h"
#include "Smoke.h"
#include "Star.h"
#include "Spark.h"
#include "Particle.h"

__private_extern__ global_info_t *info = NULL;

__private_extern__ double CurrentTime(void);

static double gTimeCounter = 0.0;
__private_extern__ void OTSetup (void) {
    if (gTimeCounter == 0.0) {
        gTimeCounter = CurrentTime();
    }
}
__private_extern__ double TimeInSecondsSinceStart (void) {
    return CurrentTime() - gTimeCounter;
}

__private_extern__ void SetupScene(global_info_t *inf)
{
    int i,k;

    info = inf;

    info->spark[0]->mystery = 1800 / 13;
    info->spark[1]->mystery = (1800 * 2) / 13;
    info->spark[2]->mystery = (1800 * 3) / 13;
    info->spark[3]->mystery = (1800 * 4) / 13;
    info->spark[4]->mystery = (1800 * 5) / 13;
    info->spark[5]->mystery = (1800 * 6) / 13;
    info->spark[6]->mystery = (1800 * 7) / 13;
    info->spark[7]->mystery = (1800 * 8) / 13;
    info->spark[8]->mystery = (1800 * 9) / 13;
    info->spark[9]->mystery = (1800 * 10) / 13;
    info->spark[10]->mystery = (1800 * 11) / 13;
    info->spark[11]->mystery = (1800 * 12) / 13;
    for (i=0;i<NUMSMOKEPARTICLES/4;i++) {
        for(k=0;k<4;k++) {
            info->s->p[i].dead.i[k] = 1;
        }
    }

    for (i=0;i<12;i++) {
        UpdateSpark(info->spark[i]);
    }

    info->fOldTime = TimeInSecondsSinceStart() + info->flurryRandomSeed;
}

__private_extern__ void UpdateScene(void)
{
    int i;

    info->dframe++;

    info->fOldTime = info->fTime;
    info->fTime = TimeInSecondsSinceStart() + info->flurryRandomSeed;
    info->fDeltaTime = info->fTime - info->fOldTime;

    info->drag = (float) pow(0.9965,info->fDeltaTime*85.0);

    for (i=0; i<numParticles; i++) {
        UpdateParticle(info->p[i]);
    }
    UpdateStar(info->star);
    for (i=0;i<info->numStreams;i++) {
        UpdateSpark(info->spark[i]);
    }

    UpdateSmoke_ScalarBase(info->s);
}

__private_extern__ void ResizeScene(float w, float h)
{
    info->sys_glWidth = w;
    info->sys_glHeight = h;
}
