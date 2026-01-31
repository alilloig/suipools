/// Hardcoded phase deadlines (ms) matching Move contract constants.
/// 1 minute before first match of each phase, 2026 FIFA World Cup schedule (UTC).

export const PHASE_DEADLINES: Record<number, number> = {
  0: 1_781_362_740_000, // Group:  Jun 11, 2026 14:59 UTC
  1: 1_783_090_740_000, // R32:    Jul 1, 2026 14:59 UTC
  2: 1_783_436_340_000, // R16:    Jul 5, 2026 14:59 UTC
  3: 1_783_781_940_000, // QF:     Jul 9, 2026 14:59 UTC
  4: 1_784_142_000_000, // SF:     Jul 13, 2026 18:59 UTC
  5: 1_784_574_000_000, // 3rd:    Jul 18, 2026 18:59 UTC
  6: 1_784_660_400_000, // Final:  Jul 19, 2026 18:59 UTC
};
