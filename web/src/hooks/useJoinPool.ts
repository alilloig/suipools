import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildJoinPoolTx } from "../services/sui/transactions/pool";

export function useJoinPool() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const joinPool = useCallback(
    async (poolId: string, entryFee: bigint) => {
      const tx = buildJoinPoolTx({ poolId, entryFee });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["getObject"] });
      await queryClient.invalidateQueries({ queryKey: ["participantData"] });
      await queryClient.invalidateQueries({ queryKey: ["joinedPools"] });

      return result;
    },
    [signAndExecute, queryClient],
  );

  return { joinPool, isPending, error };
}
