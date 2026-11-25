//
//  VCMath.c — the arithmetic of the Volume Calculator.
//

#include "VCMath.h"
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#ifndef M_LN2
#define M_LN2 0.69314718055994530942
#endif

double VCSphereVolume(double diameter)
{
    if (!(diameter > 0)) return 0;
    return M_PI * diameter * diameter * diameter / 6.0;
}

double VCChangePercent(double v1, double v2, int *ok)
{
    if (!(v1 > 0) || !(v2 > 0)) { if (ok) *ok = 0; return 0; }
    if (ok) *ok = 1;
    return 100.0 * (v2 / v1 - 1.0);
}

double VCDoublingTimeDays(double v1, double v2, double days, int *ok)
{
    if (!(v1 > 0) || !(v2 > 0) || !(days > 0)) { if (ok) *ok = 0; return 0; }
    double r = log(v2 / v1);
    if (fabs(r) < 1e-9) { if (ok) *ok = 0; return 0; }
    if (ok) *ok = 1;
    return days * M_LN2 / r;
}
