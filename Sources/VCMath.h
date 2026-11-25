//
//  VCMath.h — the arithmetic of the Volume Calculator, in plain C (tested in tests/).
//

#ifndef VCMATH_H
#define VCMATH_H

/// Volume of a sphere of diameter d: π·d³/6 (d in mm → mm³). 0 when d <= 0.
double VCSphereVolume(double diameter);

/// Volume change from v1 to v2 in percent: 100·(v2/v1 − 1). Returns 0 and sets *ok = 0 when
/// v1 or v2 is not positive.
double VCChangePercent(double v1, double v2, int *ok);

/// Volume doubling time in days: Δt·ln2 / ln(v2/v1), Δt in days. Negative when the volume
/// shrank (its absolute value is then the halving time). Sets *ok = 0 when it is undefined:
/// a volume not positive, Δt not positive, or no change.
double VCDoublingTimeDays(double v1, double v2, double days, int *ok);

#endif
