import { Badge } from "../ui/Badge";
import { PoolFields } from "../../utils/parsing/pool";
import { truncateAddress } from "../../utils/formatting/addresses";

interface PoolHeaderProps {
  poolFields: PoolFields;
  poolId: string;
}

export function PoolHeader({ poolFields, poolId }: PoolHeaderProps) {
  const statusVariant = poolFields.finalized ? "success" : "info";
  const statusLabel = poolFields.finalized ? "Finalized" : "Active";

  return (
    <div className="mb-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-white">Pool</h1>
          <p className="text-sm text-gray-400 font-mono mt-1">{truncateAddress(poolId)}</p>
        </div>
        <Badge variant={statusVariant}>{statusLabel}</Badge>
      </div>
    </div>
  );
}
