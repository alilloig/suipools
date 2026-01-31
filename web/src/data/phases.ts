import { Phase, PhaseInfo } from "../types/match";

/**
 * Phase metadata for the 2026 FIFA World Cup.
 *
 * Match index ranges MUST match scoring.move:
 *   Group   0-71   (72 matches)
 *   R32    72-87   (16 matches)
 *   R16    88-95   (8 matches)
 *   QF     96-99   (4 matches)
 *   SF    100-101  (2 matches)
 *   3rd   102      (1 match)
 *   Final 103      (1 match)
 *
 * deadlineIndex corresponds to the on-chain prediction deadline
 * for that phase (0-6).
 *
 * pointsPerMatch is the scoring weight for a correct prediction
 * in that phase.
 */
export const PHASES: PhaseInfo[] = [
  {
    phase: Phase.Group,
    label: "Group Stage",
    matchStart: 0,
    matchEnd: 72,
    deadlineIndex: 0,
    pointsPerMatch: 1,
  },
  {
    phase: Phase.R32,
    label: "Round of 32",
    matchStart: 72,
    matchEnd: 88,
    deadlineIndex: 1,
    pointsPerMatch: 2,
  },
  {
    phase: Phase.R16,
    label: "Round of 16",
    matchStart: 88,
    matchEnd: 96,
    deadlineIndex: 2,
    pointsPerMatch: 3,
  },
  {
    phase: Phase.QF,
    label: "Quarter-Finals",
    matchStart: 96,
    matchEnd: 100,
    deadlineIndex: 3,
    pointsPerMatch: 5,
  },
  {
    phase: Phase.SF,
    label: "Semi-Finals",
    matchStart: 100,
    matchEnd: 102,
    deadlineIndex: 4,
    pointsPerMatch: 8,
  },
  {
    phase: Phase.Third,
    label: "3rd Place",
    matchStart: 102,
    matchEnd: 103,
    deadlineIndex: 5,
    pointsPerMatch: 8,
  },
  {
    phase: Phase.Final,
    label: "Final",
    matchStart: 103,
    matchEnd: 104,
    deadlineIndex: 6,
    pointsPerMatch: 13,
  },
];

/** Maximum possible score: sum of all (matchCount * pointsPerMatch) */
export const MAX_POSSIBLE_SCORE = PHASES.reduce(
  (sum, p) => sum + (p.matchEnd - p.matchStart) * p.pointsPerMatch,
  0,
);

/** Look up phase info by Phase enum value */
export function getPhaseInfo(phase: Phase): PhaseInfo {
  const info = PHASES.find((p) => p.phase === phase);
  if (!info) throw new Error(`Unknown phase: ${phase}`);
  return info;
}

/** Get the phase that contains a given match index */
export function getPhaseForMatch(matchIndex: number): PhaseInfo {
  const info = PHASES.find(
    (p) => matchIndex >= p.matchStart && matchIndex < p.matchEnd,
  );
  if (!info) throw new Error(`No phase found for match index: ${matchIndex}`);
  return info;
}
