import { Card } from "../ui/Card";
import { PoolFields } from "../../utils/parsing/pool";
import { formatSui } from "../../utils/formatting/numbers";

interface PoolStatsProps {
  poolFields: PoolFields;
}

export function PoolStats({ poolFields }: PoolStatsProps) {
  const stats = [
    { label: "Entry Fee", value: formatSui(BigInt(poolFields.entryFee)) },
    { label: "Players", value: String(poolFields.participants.length) },
    { label: "Prize Pool", value: formatSui(BigInt(poolFields.prizePoolValue)) },
    { label: "Status", value: poolFields.finalized ? "Finalized" : "Active" },
  ];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
      {stats.map((stat) => (
        <Card key={stat.label} className="!p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide">{stat.label}</p>
          <p className="text-lg font-bold text-white mt-1">{stat.value}</p>
        </Card>
      ))}
    </div>
  );
}
