import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildBuySquareTx } from "../services/sui/transactions/squares";

export function useBuySquare() {
  const queryClient = useQueryClient();
  const {
    mutateAsync: signAndExecute,
    isPending,
    error,
  } = useSignAndExecuteTransaction();

  const buySquare = useCallback(
    async (poolId: string, position: number, entryFee: bigint) => {
      const tx = buildBuySquareTx({ poolId, position, entryFee });
      const result = await signAndExecute({ transaction: tx });
      await queryClient.invalidateQueries({ queryKey: ["getObject"] });
      return result;
    },
    [signAndExecute, queryClient],
  );

  return { buySquare, isPending, error };
}
