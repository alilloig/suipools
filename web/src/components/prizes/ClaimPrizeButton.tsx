import { Button } from "../ui/Button";
import { useClaimPrize } from "../../hooks/useClaimPrize";
import { formatSui } from "../../utils/formatting/numbers";

interface ClaimPrizeButtonProps {
  poolId: string;
  prizeAmount: bigint;
  claimed: boolean;
  onClaimed?: () => void;
}

export function ClaimPrizeButton({ poolId, prizeAmount, claimed, onClaimed }: ClaimPrizeButtonProps) {
  const { claimPrize, isPending } = useClaimPrize();

  if (claimed) {
    return (
      <div className="text-green-400 text-sm font-medium">
        Prize claimed ({formatSui(prizeAmount)})
      </div>
    );
  }

  if (prizeAmount === 0n) return null;

  const handleClaim = async () => {
    try {
      await claimPrize(poolId);
      onClaimed?.();
    } catch (err) {
      console.error("Failed to claim prize:", err);
    }
  };

  return (
    <Button onClick={handleClaim} loading={isPending} size="lg">
      Claim Prize ({formatSui(prizeAmount)})
    </Button>
  );
}
