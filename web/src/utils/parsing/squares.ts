import { SuiObjectResponse } from "@mysten/sui/client";

export interface SquaresPoolFields {
  id: string;
  entryFee: string;
  maxPerPlayer: string;
  prizeBps: number[];
  prizePoolValue: string;
  squaresClaimed: string;
  grid: (string | null)[];
  rowNumbers: number[];
  colNumbers: number[];
  quarterlyScores: ({ teamA: string; teamB: string } | null)[];
  quarterlyWinners: (string | null)[];
  quarterlyClaimed: boolean[];
}

export function extractSquaresPoolFields(
  response: SuiObjectResponse,
): SquaresPoolFields | null {
  const data = response.data;
  if (!data?.content || data.content.dataType !== "moveObject") return null;

  const fields = data.content.fields as Record<string, unknown>;
  const id = (fields.id as { id: string }).id;
  const entryFee = fields.entry_fee as string;
  const maxPerPlayer = fields.max_per_player as string;

  const prizeBpsRaw = fields.prize_bps as string[];
  const prizeBps = prizeBpsRaw.map(Number);

  const prizePoolValue = (fields.prize_pool as string) || "0";
  const squaresClaimed = fields.squares_claimed as string;

  // grid is vector<Option<address>> — each element is null or { vec: [address] }
  const gridRaw = fields.grid as ({ vec: string[] } | null)[];
  const grid = gridRaw.map((cell) =>
    cell && cell.vec && cell.vec.length > 0 ? cell.vec[0] : null,
  );

  const rowNumbers = (fields.row_numbers as number[]) ?? [];
  const colNumbers = (fields.col_numbers as number[]) ?? [];

  // quarterly_scores: vector<Option<QuarterScore>>
  const scoresRaw = fields.quarterly_scores as (
    | { vec: { fields: { team_a: string; team_b: string } }[] }
    | null
  )[];
  const quarterlyScores = scoresRaw.map((s) =>
    s && s.vec && s.vec.length > 0
      ? { teamA: s.vec[0].fields.team_a, teamB: s.vec[0].fields.team_b }
      : null,
  );

  // quarterly_winners: vector<Option<address>>
  const winnersRaw = fields.quarterly_winners as ({ vec: string[] } | null)[];
  const quarterlyWinners = winnersRaw.map((w) =>
    w && w.vec && w.vec.length > 0 ? w.vec[0] : null,
  );

  const quarterlyClaimed = fields.quarterly_claimed as boolean[];

  return {
    id,
    entryFee,
    maxPerPlayer,
    prizeBps,
    prizePoolValue,
    squaresClaimed,
    grid,
    rowNumbers,
    colNumbers,
    quarterlyScores,
    quarterlyWinners,
    quarterlyClaimed,
  };
}

export interface SquaresCapFields {
  id: string;
  poolId: string;
}

export function extractSquaresCapFields(
  response: SuiObjectResponse,
): SquaresCapFields | null {
  const data = response.data;
  if (!data?.content || data.content.dataType !== "moveObject") return null;

  const fields = data.content.fields as Record<string, unknown>;
  const id = (fields.id as { id: string }).id;
  const poolId = fields.pool_id as string;

  return { id, poolId };
}
