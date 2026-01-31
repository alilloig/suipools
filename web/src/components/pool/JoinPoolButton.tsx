import { useCurrentAccount } from "@mysten/dapp-kit";
import { Button } from "../ui/Button";
import { useJoinPool } from "../../hooks/useJoinPool";
import { formatSui } from "../../utils/formatting/numbers";

interface JoinPoolButtonProps {
  poolId: string;
  entryFee: string;
  participants: string[];
  finalized: boolean;
  onJoined?: () => void;
}

export function JoinPoolButton({ poolId, entryFee, participants, finalized, onJoined }: JoinPoolButtonProps) {
  const account = useCurrentAccount();
  const { joinPool, isPending } = useJoinPool();

  if (!account) return null;
  if (finalized) return null;

  const alreadyJoined = participants.includes(account.address);
  if (alreadyJoined) return null;

  const fee = BigInt(entryFee);

  const handleJoin = async () => {
    try {
      await joinPool(poolId, fee);
      onJoined?.();
    } catch (err) {
      console.error("Failed to join pool:", err);
    }
  };

  return (
    <Button onClick={handleJoin} loading={isPending} size="lg">
      Join Pool {fee > 0n ? `(${formatSui(fee)})` : "(Free)"}
    </Button>
  );
}
