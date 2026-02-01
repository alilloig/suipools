import { getPackageId } from "./env";

export const POOL_MODULE = "pool";
export const TOURNAMENT_MODULE = "tournament";

export const POOL_ENTRY_FUNCTIONS = {
  create: "create",
  join: "join",
  placeBets: "place_bets",
  finalize: "finalize",
  claimPrize: "claim_prize",
  withdrawRemainder: "withdraw_remainder",
} as const;

export const TOURNAMENT_ENTRY_FUNCTIONS = {
  enterResults: "enter_results",
  advancePhase: "advance_phase",
} as const;

export const POOL_VIEW_FUNCTIONS = {
  entryFee: "entry_fee",
  prizeBps: "prize_bps",
  participantCount: "participant_count",
  prizePoolValue: "prize_pool_value",
  isFinalized: "is_finalized",
  participantPoints: "participant_points",
  participantBets: "participant_bets",
  participantPrize: "participant_prize",
  participantClaimed: "participant_claimed",
  leaderboard: "leaderboard",
  participants: "participants",
  isParticipant: "is_participant",
  capPoolId: "cap_pool_id",
  leaderboardEntryParticipant: "leaderboard_entry_participant",
  leaderboardEntryPoints: "leaderboard_entry_points",
} as const;

export const TOURNAMENT_VIEW_FUNCTIONS = {
  results: "results",
  resultsEntered: "results_entered",
  currentPhase: "current_phase",
  groupPhaseComplete: "group_phase_complete",
} as const;

export function poolTarget(fn: string): `${string}::${string}::${string}` {
  return `${getPackageId()}::${POOL_MODULE}::${fn}`;
}

export function tournamentTarget(fn: string): `${string}::${string}::${string}` {
  return `${getPackageId()}::${TOURNAMENT_MODULE}::${fn}`;
}

// Type constructors for querying owned objects
export function poolCreatorCapType(): string {
  return `${getPackageId()}::${POOL_MODULE}::PoolCreatorCap`;
}

export function adminCapType(): string {
  return `${getPackageId()}::${TOURNAMENT_MODULE}::AdminCap`;
}

export const SQUARES_MODULE = "squares";

export const SQUARES_ENTRY_FUNCTIONS = {
  create: "create",
  buySquare: "buy_square",
  assignNumbers: "assign_numbers",
  enterScore: "enter_score",
  claimPrize: "claim_prize",
  withdrawRemainder: "withdraw_remainder",
} as const;

export function squaresTarget(fn: string): `${string}::${string}::${string}` {
  return `${getPackageId()}::${SQUARES_MODULE}::${fn}`;
}

export function squaresCreatorCapType(): string {
  return `${getPackageId()}::${SQUARES_MODULE}::SquaresCreatorCap`;
}
