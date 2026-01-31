import { Phase } from "../../types/match";
import { POINTS_BY_PHASE, GROUP_BONUS_POINTS, MATCHES_PER_GROUP, NUM_GROUPS } from "../../constants/pool";

export function phaseForMatch(matchIndex: number): Phase {
  if (matchIndex < 72) return Phase.Group;
  if (matchIndex < 88) return Phase.R32;
  if (matchIndex < 96) return Phase.R16;
  if (matchIndex < 100) return Phase.QF;
  if (matchIndex < 102) return Phase.SF;
  if (matchIndex === 102) return Phase.Third;
  return Phase.Final;
}

export function pointsForMatch(matchIndex: number): number {
  return POINTS_BY_PHASE[phaseForMatch(matchIndex)];
}

export function groupIndexForMatch(matchIndex: number): number {
  if (matchIndex >= 72) throw new Error("Not a group stage match");
  return Math.floor(matchIndex / MATCHES_PER_GROUP);
}

export function isGroupComplete(results: number[], groupIndex: number): boolean {
  const start = groupIndex * MATCHES_PER_GROUP;
  for (let i = 0; i < MATCHES_PER_GROUP; i++) {
    if (results[start + i] === 0) return false;
  }
  return true;
}

export function checkGroupBonus(bets: number[], results: number[], groupIndex: number): number {
  const start = groupIndex * MATCHES_PER_GROUP;
  for (let i = 0; i < MATCHES_PER_GROUP; i++) {
    if (bets[start + i] !== results[start + i]) return 0;
  }
  return GROUP_BONUS_POINTS;
}

/**
 * Compute total score for a participant's bets against tournament results.
 * Mirrors the Move `scoring::compute_total_score` logic exactly.
 */
export function computeTotalScore(bets: number[], results: number[]): number {
  let total = 0;

  // Match points
  for (let i = 0; i < 104; i++) {
    if (bets[i] !== 0 && results[i] !== 0 && bets[i] === results[i]) {
      total += pointsForMatch(i);
    }
  }

  // Group bonuses
  for (let g = 0; g < NUM_GROUPS; g++) {
    if (isGroupComplete(results, g)) {
      total += checkGroupBonus(bets, results, g);
    }
  }

  return total;
}
