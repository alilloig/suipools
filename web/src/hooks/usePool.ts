import { useSuiClientQuery } from "@mysten/dapp-kit";
import { extractPoolFields, PoolFields } from "../utils/parsing/pool";

export function usePool(poolId: string | undefined) {
  const { data, isLoading, error, refetch } = useSuiClientQuery(
    "getObject",
    {
      id: poolId!,
      options: {
        showContent: true,
      },
    },
    {
      enabled: !!poolId,
    },
  );

  const poolFields: PoolFields | null = data ? extractPoolFields(data) : null;

  return { poolFields, isLoading, error, refetch };
}
