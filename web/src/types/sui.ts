export interface CreatePoolParams {
  entryFee: bigint;
  prizeBps: number[];
}

export interface JoinPoolParams {
  poolId: string;
  entryFee: bigint;
}

export interface PlaceBetsParams {
  poolId: string;
  tournamentId: string;
  matchIndices: number[];
  outcomes: number[];
}

export interface FinalizeParams {
  poolId: string;
  capId: string;
  tournamentId: string;
}

export interface ClaimPrizeParams {
  poolId: string;
}

export interface WithdrawRemainderParams {
  poolId: string;
  capId: string;
}

export interface EnterTournamentResultsParams {
  tournamentId: string;
  adminCapId: string;
  matchIndices: number[];
  outcomes: number[];
}

export interface AdvancePhaseParams {
  tournamentId: string;
  adminCapId: string;
}
