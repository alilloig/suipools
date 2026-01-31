import { useCurrentAccount } from "@mysten/dapp-kit";
import { LeaderboardRow } from "./LeaderboardRow";
import { Card } from "../ui/Card";
import { EmptyState } from "../ui/EmptyState";

interface LeaderboardEntry {
  participant: string;
  points: number;
  prizeAmount?: bigint;
}

interface LeaderboardTableProps {
  entries: LeaderboardEntry[];
}

export function LeaderboardTable({ entries }: LeaderboardTableProps) {
  const account = useCurrentAccount();

  if (entries.length === 0) {
    return <EmptyState title="No leaderboard data" description="The pool has not been finalized yet." />;
  }

  return (
    <Card className="!p-0 overflow-hidden">
      <table className="w-full">
        <thead className="bg-gray-900/50">
          <tr className="border-b border-gray-700">
            <th className="py-3 px-4 text-left text-xs font-medium text-gray-400 uppercase">Rank</th>
            <th className="py-3 px-4 text-left text-xs font-medium text-gray-400 uppercase">Player</th>
            <th className="py-3 px-4 text-right text-xs font-medium text-gray-400 uppercase">Points</th>
            <th className="py-3 px-4 text-right text-xs font-medium text-gray-400 uppercase">Prize</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry, idx) => (
            <LeaderboardRow
              key={entry.participant}
              rank={idx + 1}
              address={entry.participant}
              points={entry.points}
              prizeAmount={entry.prizeAmount}
              isCurrentUser={account?.address === entry.participant}
            />
          ))}
        </tbody>
      </table>
    </Card>
  );
}
