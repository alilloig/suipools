import { useSuiClient, useCurrentAccount } from "@mysten/dapp-kit";
import { useQuery } from "@tanstack/react-query";
import { usePoolCreatorCaps } from "./usePoolCreatorCaps";
import { getPackageId } from "../constants/env";
import { POOL_MODULE } from "../constants/blockchain";

export interface MyPoolsData {
  createdPoolIds: string[];
  joinedPoolIds: string[];
}

export function useMyPools() {
  const client = useSuiClient();
  const account = useCurrentAccount();
  const { caps, isLoading: capsLoading } = usePoolCreatorCaps();

  const createdPoolIds = caps.map((c) => c.poolId);

  const { data: joinedPoolIds, isLoading: eventsLoading, error } = useQuery<string[]>({
    queryKey: ["joinedPools", account?.address],
    queryFn: async () => {
      if (!account?.address) return [];

      const eventType = `${getPackageId()}::${POOL_MODULE}::ParticipantJoined`;

      const events = await client.queryEvents({
        query: { MoveEventType: eventType },
        limit: 50,
      });

      const poolIds = events.data
        .filter((e) => {
          const parsed = e.parsedJson as { participant: string; pool_id: string };
          return parsed.participant === account.address;
        })
        .map((e) => (e.parsedJson as { pool_id: string }).pool_id);

      // Deduplicate
      return [...new Set(poolIds)];
    },
    enabled: !!account?.address,
  });

  return {
    createdPoolIds,
    joinedPoolIds: joinedPoolIds ?? [],
    isLoading: capsLoading || eventsLoading,
    error,
  };
}
