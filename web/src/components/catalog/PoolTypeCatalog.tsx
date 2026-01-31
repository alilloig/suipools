import { POOL_TYPES } from "../../data/poolTypes";
import { PoolTypeCard } from "./PoolTypeCard";

export function PoolTypeCatalog() {
  return (
    <section>
      <h2 className="text-lg font-bold text-white mb-3">Available Pools</h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {POOL_TYPES.map((pt) => (
          <PoolTypeCard key={pt.id} poolType={pt} />
        ))}
      </div>
    </section>
  );
}
