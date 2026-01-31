export enum Outcome {
  None = 0,
  Home = 1,
  Draw = 2,
  Away = 3,
}

export interface PoolData {
  id: string;
  entryFee: bigint;
  prizeBps: number[];
  prizePoolValue: bigint;
  participants: string[];
  finalized: boolean;
  claimsMade: number;
  leaderboard: LeaderboardEntry[];
}

export interface TournamentData {
  id: string;
  results: number[];
  resultsEntered: number;
  currentPhase: number;
  groupPhaseComplete: boolean;
}

export interface ParticipantData {
  bets: number[];
  points: number;
  prizeAmount: bigint;
  claimed: boolean;
}

export interface LeaderboardEntry {
  participant: string;
  points: number;
}

export type PoolRole = "creator" | "participant" | "visitor";
