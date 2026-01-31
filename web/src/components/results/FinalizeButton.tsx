import { Button } from "../ui/Button";
import { useFinalizePool } from "../../hooks/useFinalizePool";
import { TOTAL_MATCHES } from "../../constants/pool";

interface FinalizeButtonProps {
  poolId: string;
  capId: string;
  resultsEntered: number;
  finalized: boolean;
  onFinalized?: () => void;
}

export function FinalizeButton({ poolId, capId, resultsEntered, finalized, onFinalized }: FinalizeButtonProps) {
  const { finalizePool, isPending } = useFinalizePool();

  if (finalized) return null;

  const allResultsEntered = resultsEntered >= TOTAL_MATCHES;

  const handleFinalize = async () => {
    try {
      await finalizePool(poolId, capId);
      onFinalized?.();
    } catch (err) {
      console.error("Failed to finalize:", err);
    }
  };

  return (
    <Button
      onClick={handleFinalize}
      loading={isPending}
      disabled={!allResultsEntered}
      size="lg"
      variant={allResultsEntered ? "primary" : "secondary"}
    >
      {allResultsEntered ? "Finalize Pool" : `Enter all results first (${resultsEntered}/${TOTAL_MATCHES})`}
    </Button>
  );
}
