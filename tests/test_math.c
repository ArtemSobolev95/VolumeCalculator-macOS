// cc -o tm test_math.c ../Sources/VCMath.c -lm && ./tm
#include "../Sources/VCMath.h"
#include <math.h>
#include <stdio.h>
static int fails = 0;
static void near(const char *what, double got, double want, double tol) {
    if (fabs(got - want) > tol) { printf("FAIL %s: got %.6f want %.6f\n", what, got, want); fails++; }
    else printf("ok   %s = %.4f\n", what, got);
}
int main(void) {
    int ok;
    near("V(10 mm)", VCSphereVolume(10), 523.5988, 1e-3);           // pi*1000/6
    near("V(0)", VCSphereVolume(0), 0, 0);
    near("V(-3)", VCSphereVolume(-3), 0, 0);
    // diameter x1.26 ~ volume x2
    double v1 = VCSphereVolume(10), v2 = VCSphereVolume(10 * cbrt(2.0));
    near("change, doubled", VCChangePercent(v1, v2, &ok), 100, 1e-6); if (!ok) fails++;
    near("change, halved", VCChangePercent(v2, v1, &ok), -50, 1e-6);
    VCChangePercent(0, v2, &ok); if (ok) { puts("FAIL change v1=0 ok"); fails++; }
    near("VDT doubled in 100 d", VCDoublingTimeDays(v1, v2, 100, &ok), 100, 1e-6); if (!ok) fails++;
    near("VDT halved in 100 d", VCDoublingTimeDays(v2, v1, 100, &ok), -100, 1e-6);
    // 8 mm -> 10 mm in 90 days: 90*ln2/(3 ln(10/8)) = 93.19
    near("VDT 8->10 mm / 90 d", VCDoublingTimeDays(VCSphereVolume(8), VCSphereVolume(10), 90, &ok), 93.1885, 1e-3);
    VCDoublingTimeDays(v1, v1, 100, &ok); if (ok) { puts("FAIL VDT no change ok"); fails++; }
    VCDoublingTimeDays(v1, v2, 0, &ok); if (ok) { puts("FAIL VDT 0 days ok"); fails++; }
    printf(fails ? "%d FAILED\n" : "all passed\n", fails);
    return fails != 0;
}
