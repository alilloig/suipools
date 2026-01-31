import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildAdvancePhaseTx } from "../services/sui/transactions/tournament";
import { getTournamentId } from "../constants/env";

export function useAdvancePhase() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const advancePhase = useCallback(
    async (adminCapId: string) => {
      const tournamentId = getTournamentId();
      const tx = buildAdvancePhaseTx({ tournamentId, adminCapId });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["getObject"] });

      return result;
    },
    [signAndExecute, queryClient],
  );

  return { advancePhase, isPending, error };
}
