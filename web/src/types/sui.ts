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

export interface CreateSquaresPoolParams {
  entryFee: bigint;
  maxPerPlayer: number;
  prizeBps: number[];
}

export interface BuySquareParams {
  poolId: string;
  position: number;
  entryFee: bigint;
}

export interface AssignNumbersParams {
  poolId: string;
}

export interface EnterScoreParams {
  poolId: string;
  capId: string;
  quarter: number;
  teamAScore: number;
  teamBScore: number;
}

export interface ClaimSquaresPrizeParams {
  poolId: string;
  quarter: number;
}

export interface WithdrawSquaresRemainderParams {
  poolId: string;
  capId: string;
}
