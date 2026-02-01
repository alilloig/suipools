import { useSuiClient, useCurrentAccount } from "@mysten/dapp-kit";
import { useQuery } from "@tanstack/react-query";
import { useSquaresCreatorCaps } from "./useSquaresCreatorCaps";
import { getPackageId } from "../constants/env";
import { SQUARES_MODULE } from "../constants/blockchain";

export function useMySquaresPools() {
  const client = useSuiClient();
  const account = useCurrentAccount();
  const { caps, isLoading: capsLoading } = useSquaresCreatorCaps();

  const createdPoolIds = caps.map((c) => c.poolId);

  const {
    data: boughtPoolIds,
    isLoading: eventsLoading,
    error,
  } = useQuery<string[]>({
    queryKey: ["squaresBoughtPools", account?.address],
    queryFn: async () => {
      if (!account?.address) return [];

      const eventType = `${getPackageId()}::${SQUARES_MODULE}::SquareBought`;
      const events = await client.queryEvents({
        query: { MoveEventType: eventType },
        limit: 50,
      });

      const poolIds = events.data
        .filter((e) => {
          const parsed = e.parsedJson as { buyer: string };
          return parsed.buyer === account.address;
        })
        .map((e) => (e.parsedJson as { pool_id: string }).pool_id);

      return [...new Set(poolIds)];
    },
    enabled: !!account?.address,
  });

  return {
    createdPoolIds,
    boughtPoolIds: boughtPoolIds ?? [],
    isLoading: capsLoading || eventsLoading,
    error,
  };
}
