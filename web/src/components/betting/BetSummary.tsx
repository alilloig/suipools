import { Button } from "../ui/Button";

interface BetSummaryProps {
  pendingCount: number;
  onSubmit: () => void;
  isPending: boolean;
}

export function BetSummary({ pendingCount, onSubmit, isPending }: BetSummaryProps) {
  if (pendingCount === 0) return null;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-30 bg-gray-900/95 border-t border-gray-700 backdrop-blur-sm">
      <div className="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
        <p className="text-sm text-gray-300">
          <span className="font-bold text-white">{pendingCount}</span> pending bet{pendingCount !== 1 ? "s" : ""}
        </p>
        <Button onClick={onSubmit} loading={isPending}>
          Submit Bets
        </Button>
      </div>
    </div>
  );
}
