import { useSuiClientQuery } from "@mysten/dapp-kit";
import {
  extractSquaresPoolFields,
  SquaresPoolFields,
} from "../utils/parsing/squares";

export function useSquaresPool(poolId: string | undefined) {
  const { data, isLoading, error, refetch } = useSuiClientQuery(
    "getObject",
    {
      id: poolId!,
      options: { showContent: true },
    },
    { enabled: !!poolId },
  );

  const poolFields: SquaresPoolFields | null = data
    ? extractSquaresPoolFields(data)
    : null;

  return { poolFields, isLoading, error, refetch };
}
