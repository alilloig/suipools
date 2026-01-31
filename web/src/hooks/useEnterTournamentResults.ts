import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildEnterTournamentResultsTx } from "../services/sui/transactions/tournament";
import { getTournamentId } from "../constants/env";

export function useEnterTournamentResults() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const enterResults = useCallback(
    async (adminCapId: string, matchIndices: number[], outcomes: number[]) => {
      const tournamentId = getTournamentId();
      const tx = buildEnterTournamentResultsTx({ tournamentId, adminCapId, matchIndices, outcomes });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["getObject"] });

      return result;
    },
    [signAndExecute, queryClient],
  );

  return { enterResults, isPending, error };
}
