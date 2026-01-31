import { usePoolCreatorCaps } from "./usePoolCreatorCaps";

export function useIsPoolCreator(poolId: string | undefined) {
  const { caps, isLoading, error } = usePoolCreatorCaps();

  const matchingCap = poolId
    ? caps.find((c) => c.poolId === poolId)
    : undefined;

  return {
    isCreator: !!matchingCap,
    capId: matchingCap?.id ?? null,
    isLoading,
    error,
  };
}
