import { Button } from "../ui/Button";
import { useWithdrawRemainder } from "../../hooks/useWithdrawRemainder";

interface WithdrawButtonProps {
  poolId: string;
  capId: string;
  onWithdrawn?: () => void;
}

export function WithdrawButton({ poolId, capId, onWithdrawn }: WithdrawButtonProps) {
  const { withdrawRemainder, isPending } = useWithdrawRemainder();

  const handleWithdraw = async () => {
    try {
      await withdrawRemainder(poolId, capId);
      onWithdrawn?.();
    } catch (err) {
      console.error("Failed to withdraw:", err);
    }
  };

  return (
    <Button onClick={handleWithdraw} loading={isPending} variant="secondary">
      Withdraw Remainder
    </Button>
  );
}
