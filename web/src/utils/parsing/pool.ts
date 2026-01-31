import { SuiObjectResponse } from "@mysten/sui/client";

export interface PoolFields {
  id: string;
  entryFee: string;
  prizeBps: number[];
  prizePoolValue: string;
  participants: string[];
  finalized: boolean;
  claimsMade: string;
}

export function extractPoolFields(response: SuiObjectResponse): PoolFields | null {
  const data = response.data;
  if (!data?.content || data.content.dataType !== "moveObject") return null;

  const fields = data.content.fields as Record<string, unknown>;
  const id = (fields.id as { id: string }).id;
  const entryFee = fields.entry_fee as string;

  // prize_bps is a vector<u64>
  const prizeBpsRaw = fields.prize_bps as string[];
  const prizeBps = prizeBpsRaw.map(Number);

  // prize_pool is a Balance<SUI>, serialized as a plain string
  const prizePoolValue = (fields.prize_pool as string) || "0";

  // participants is a vector<address>
  const participants = fields.participants as string[];

  const finalized = fields.finalized as boolean;
  const claimsMade = fields.claims_made as string;

  return {
    id,
    entryFee,
    prizeBps,
    prizePoolValue,
    participants,
    finalized,
    claimsMade,
  };
}

export interface TournamentFields {
  id: string;
  results: number[];
  resultsEntered: string;
  currentPhase: number;
  groupPhaseComplete: boolean;
}

export function extractTournamentFields(response: SuiObjectResponse): TournamentFields | null {
  const data = response.data;
  if (!data?.content || data.content.dataType !== "moveObject") return null;

  const fields = data.content.fields as Record<string, unknown>;
  const id = (fields.id as { id: string }).id;
  const results = fields.results as number[];
  const resultsEntered = fields.results_entered as string;
  const currentPhase = Number(fields.current_phase);
  const groupPhaseComplete = fields.group_phase_complete as boolean;

  return {
    id,
    results,
    resultsEntered,
    currentPhase,
    groupPhaseComplete,
  };
}

export interface CapFields {
  id: string;
  poolId: string;
}

export function extractCapFields(response: SuiObjectResponse): CapFields | null {
  const data = response.data;
  if (!data?.content || data.content.dataType !== "moveObject") return null;

  const fields = data.content.fields as Record<string, unknown>;
  const id = (fields.id as { id: string }).id;
  const poolId = fields.pool_id as string;

  return { id, poolId };
}
