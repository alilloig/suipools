import { Card } from "../ui/Card";
import { formatSui } from "../../utils/formatting/numbers";

interface PrizeBreakdownProps {
  prizeBps: number[];
  prizePoolValue: bigint;
  participantCount: number;
}

function positionLabel(idx: number): string {
  const n = idx + 1;
  if (n === 1) return "1st";
  if (n === 2) return "2nd";
  if (n === 3) return "3rd";
  return `${n}th`;
}

export function PrizeBreakdown({ prizeBps, prizePoolValue, participantCount }: PrizeBreakdownProps) {
  const numSlots = Math.min(participantCount, prizeBps.length);
  let totalBp = 0;
  for (let i = 0; i < numSlots; i++) {
    totalBp += prizeBps[i];
  }

  return (
    <Card>
      <h3 className="text-sm font-bold text-gray-300 mb-3 uppercase tracking-wider">Prize Distribution</h3>
      <div className="space-y-2">
        {prizeBps.slice(0, numSlots).map((bp, idx) => {
          const amount = totalBp > 0
            ? (prizePoolValue * BigInt(bp)) / BigInt(totalBp)
            : 0n;

          return (
            <div key={idx} className="flex items-center justify-between text-sm">
              <span className="text-gray-400">{positionLabel(idx)}</span>
              <div className="flex items-center gap-3">
                <span className="text-gray-500">{(bp / 100).toFixed(1)}%</span>
                <span className="text-white font-medium">{formatSui(amount)}</span>
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
}
