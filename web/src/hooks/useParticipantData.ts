import { useSuiClient, useCurrentAccount } from "@mysten/dapp-kit";
import { useQuery } from "@tanstack/react-query";
import { Transaction } from "@mysten/sui/transactions";
import { poolTarget, POOL_VIEW_FUNCTIONS } from "../constants/blockchain";
import { ParticipantData } from "../types/pool";
import { parseU64, parseBool, parseVectorU8 } from "../utils/parsing/bcs";

export function useParticipantData(poolId: string | undefined) {
  const client = useSuiClient();
  const account = useCurrentAccount();

  return useQuery<ParticipantData | null>({
    queryKey: ["participantData", poolId, account?.address],
    queryFn: async () => {
      if (!poolId || !account?.address) return null;

      const tx = new Transaction();

      tx.moveCall({
        target: poolTarget(POOL_VIEW_FUNCTIONS.participantBets),
        arguments: [tx.object(poolId), tx.pure.address(account.address)],
      });
      tx.moveCall({
        target: poolTarget(POOL_VIEW_FUNCTIONS.participantPoints),
        arguments: [tx.object(poolId), tx.pure.address(account.address)],
      });
      tx.moveCall({
        target: poolTarget(POOL_VIEW_FUNCTIONS.participantPrize),
        arguments: [tx.object(poolId), tx.pure.address(account.address)],
      });
      tx.moveCall({
        target: poolTarget(POOL_VIEW_FUNCTIONS.participantClaimed),
        arguments: [tx.object(poolId), tx.pure.address(account.address)],
      });

      const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: account.address,
      });

      if (result.effects.status.status !== "success" || !result.results) {
        return null;
      }

      const betsBytes = new Uint8Array(result.results[0].returnValues![0][0] as number[]);
      const pointsBytes = new Uint8Array(result.results[1].returnValues![0][0] as number[]);
      const prizeBytes = new Uint8Array(result.results[2].returnValues![0][0] as number[]);
      const claimedBytes = new Uint8Array(result.results[3].returnValues![0][0] as number[]);

      const bets = parseVectorU8(betsBytes);
      const points = Number(parseU64(pointsBytes));
      const prizeAmount = parseU64(prizeBytes);
      const claimed = parseBool(claimedBytes);

      return { bets, points, prizeAmount, claimed };
    },
    enabled: !!poolId && !!account?.address,
  });
}
