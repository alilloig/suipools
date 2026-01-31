import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildClaimPrizeTx } from "../services/sui/transactions/pool";

export function useClaimPrize() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const claimPrize = useCallback(
    async (poolId: string) => {
      const tx = buildClaimPrizeTx({ poolId });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["getObject"] });
      await queryClient.invalidateQueries({ queryKey: ["participantData"] });

      return result;
    },
    [signAndExecute, queryClient],
  );

  return { claimPrize, isPending, error };
}
