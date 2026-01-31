import { useCurrentAccount, useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";
import { buildCreatePoolTx } from "../services/sui/transactions/pool";

export function useCreatePool() {
  const account = useCurrentAccount();
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute, isPending, error } = useSignAndExecuteTransaction();

  const createPool = useCallback(
    async (entryFee: bigint, prizeBps: number[]) => {
      if (!account?.address) throw new Error("Wallet not connected");

      const tx = buildCreatePoolTx({ entryFee, prizeBps, sender: account.address });

      const result = await signAndExecute({ transaction: tx });

      await queryClient.invalidateQueries({ queryKey: ["getOwnedObjects"] });

      return result;
    },
    [account, signAndExecute, queryClient],
  );

  return { createPool, isPending, error };
}
