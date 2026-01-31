import { Link } from "react-router-dom";
import { Card } from "../ui/Card";
import { Badge } from "../ui/Badge";
import { usePool } from "../../hooks/usePool";
import { formatSui } from "../../utils/formatting/numbers";
import { Spinner } from "../ui/Spinner";

interface PoolCardProps {
  poolId: string;
  linkTo: string;
  badge?: string;
}

export function PoolCard({ poolId, linkTo, badge }: PoolCardProps) {
  const { poolFields, isLoading } = usePool(poolId);

  if (isLoading) {
    return (
      <Card className="animate-pulse">
        <Spinner className="w-5 h-5" />
      </Card>
    );
  }

  if (!poolFields) {
    return (
      <Card>
        <p className="text-gray-500 text-sm">Pool not found</p>
      </Card>
    );
  }

  const statusVariant = poolFields.finalized ? "success" : "info";
  const statusLabel = poolFields.finalized ? "Finalized" : "Active";

  return (
    <Link to={linkTo}>
      <Card className="hover:border-pitch-light transition-colors">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <p className="text-sm text-gray-400 truncate font-mono">
                {poolId.slice(0, 10)}...{poolId.slice(-6)}
              </p>
              {badge && (
                <span className="text-xs font-medium text-yellow-400 bg-yellow-400/10 px-1.5 py-0.5 rounded">
                  {badge}
                </span>
              )}
            </div>
            <div className="flex items-center gap-3 mt-2 text-sm text-gray-300">
              <span>Fee: {formatSui(BigInt(poolFields.entryFee))}</span>
              <span>{poolFields.participants.length} players</span>
            </div>
          </div>
          <Badge variant={statusVariant}>{statusLabel}</Badge>
        </div>
      </Card>
    </Link>
  );
}
