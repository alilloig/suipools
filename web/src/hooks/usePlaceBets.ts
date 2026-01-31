import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildPlaceBetsTx } from "../services/sui/transactions/pool";
import { getTournamentId } from "../constants/env";

export function usePlaceBets() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const placeBets = useCallback(
    async (poolId: string, matchIndices: number[], outcomes: number[]) => {
      const tournamentId = getTournamentId();
      const tx = buildPlaceBetsTx({ poolId, tournamentId, matchIndices, outcomes });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["participantData"] });
      await queryClient.invalidateQueries({ queryKey: ["getObject"] });

      return result;
    },
    [signAndExecute, queryClient],
  );

  return { placeBets, isPending, error };
}
