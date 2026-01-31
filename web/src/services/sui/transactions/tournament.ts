import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { tournamentTarget, TOURNAMENT_ENTRY_FUNCTIONS } from "../../../constants/blockchain";
import {
  EnterTournamentResultsParams,
  AdvancePhaseParams,
} from "../../../types/sui";

export function buildEnterTournamentResultsTx(params: EnterTournamentResultsParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: tournamentTarget(TOURNAMENT_ENTRY_FUNCTIONS.enterResults),
    arguments: [
      tx.object(params.tournamentId),
      tx.object(params.adminCapId),
      tx.pure(bcs.vector(bcs.U64).serialize(params.matchIndices)),
      tx.pure(bcs.vector(bcs.U8).serialize(params.outcomes)),
    ],
  });

  return tx;
}

export function buildAdvancePhaseTx(params: AdvancePhaseParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: tournamentTarget(TOURNAMENT_ENTRY_FUNCTIONS.advancePhase),
    arguments: [
      tx.object(params.tournamentId),
      tx.object(params.adminCapId),
    ],
  });

  return tx;
}
