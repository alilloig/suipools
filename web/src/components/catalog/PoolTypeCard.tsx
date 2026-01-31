import { Link } from "react-router-dom";
import type { PoolType } from "../../data/poolTypes";

interface PoolTypeCardProps {
  poolType: PoolType;
}

export function PoolTypeCard({ poolType }: PoolTypeCardProps) {
  const card = (
    <div
      className={`bg-gray-800/80 border rounded-xl p-6 transition-all ${
        poolType.enabled
          ? "border-gray-700 hover:border-pitch-light cursor-pointer"
          : "border-gray-700/50 opacity-50 cursor-not-allowed"
      }`}
    >
      <div className="text-4xl mb-3">{poolType.icon}</div>
      <h3 className="font-display font-semibold text-lg text-white">{poolType.title}</h3>
      <p className="text-sm text-gray-400 mt-1">{poolType.tagline}</p>
      {!poolType.enabled && (
        <span className="inline-block mt-3 text-xs font-medium text-gray-500 bg-gray-700/60 px-2 py-0.5 rounded-full">
          Coming Soon
        </span>
      )}
    </div>
  );

  if (poolType.enabled) {
    return <Link to={poolType.route}>{card}</Link>;
  }

  return card;
}
