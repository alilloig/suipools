import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildWithdrawRemainderTx } from "../services/sui/transactions/pool";

export function useWithdrawRemainder() {
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const withdrawRemainder = useCallback(
    async (poolId: string, capId: string) => {
      const tx = buildWithdrawRemainderTx({ poolId, capId });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["getObject"] });

      return result;
    },
    [signAndExecute, queryClient],
  );

  return { withdrawRemainder, isPending, error };
}
