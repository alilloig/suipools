import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildFinalizeTx } from "../services/sui/transactions/pool";
import { getTournamentId } from "../constants/env";

export function useFinalizePool() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const finalizePool = useCallback(
    async (poolId: string, capId: string) => {
      const tournamentId = getTournamentId();
      const tx = buildFinalizeTx({ poolId, capId, tournamentId });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["getObject"] });
      await queryClient.invalidateQueries({ queryKey: ["participantData"] });

      return result;
    },
    [signAndExecute, queryClient],
  );

  return { finalizePool, isPending, error };
}
