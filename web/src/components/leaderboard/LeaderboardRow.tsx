import { truncateAddress, getExplorerUrl } from "../../utils/formatting/addresses";
import { formatSui } from "../../utils/formatting/numbers";

interface LeaderboardRowProps {
  rank: number;
  address: string;
  points: number;
  prizeAmount?: bigint;
  isCurrentUser?: boolean;
}

export function LeaderboardRow({ rank, address, points, prizeAmount, isCurrentUser }: LeaderboardRowProps) {
  return (
    <tr className={`border-b border-gray-700/50 ${isCurrentUser ? "bg-pitch-dark/30" : ""}`}>
      <td className="py-3 px-4 text-sm">
        <span className={`font-bold ${rank <= 3 ? "text-gold" : "text-gray-400"}`}>
          #{rank}
        </span>
      </td>
      <td className="py-3 px-4 text-sm">
        <a
          href={getExplorerUrl(address, "address")}
          target="_blank"
          rel="noopener noreferrer"
          className="text-gray-300 hover:text-white font-mono"
        >
          {truncateAddress(address)}
          {isCurrentUser && <span className="ml-2 text-pitch-light">(You)</span>}
        </a>
      </td>
      <td className="py-3 px-4 text-sm text-right font-medium text-white">
        {points}
      </td>
      <td className="py-3 px-4 text-sm text-right text-gray-400">
        {prizeAmount !== undefined && prizeAmount > 0n ? formatSui(prizeAmount) : "\u2014"}
      </td>
    </tr>
  );
}
