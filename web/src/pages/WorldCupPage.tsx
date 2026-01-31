import { useState, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { Spinner } from "../components/ui/Spinner";
import { PoolCard } from "../components/pool/PoolCard";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { useMyPools } from "../hooks/useMyPools";

export function WorldCupPage() {
  const account = useCurrentAccount();
  const { createdPoolIds, joinedPoolIds, isLoading } = useMyPools();
  const navigate = useNavigate();
  const [joinId, setJoinId] = useState("");

  const handleJoinById = () => {
    const id = joinId.trim();
    if (id) {
      navigate(`/pool/${id}`);
    }
  };

  const allPoolIds = useMemo(() => {
    const set = new Set([...createdPoolIds, ...joinedPoolIds]);
    return [...set];
  }, [createdPoolIds, joinedPoolIds]);

  const createdSet = useMemo(() => new Set(createdPoolIds), [createdPoolIds]);

  if (!account) {
    return <ConnectPrompt message="Connect your wallet to manage World Cup pools" />;
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold text-white">World Cup 2026</h1>

      {/* Actions */}
      <div className="flex flex-wrap gap-3">
        <Link to="/create">
          <Button size="lg">Create New Pool</Button>
        </Link>
      </div>

      {/* Join by ID */}
      <Card>
        <h2 className="text-lg font-bold text-white mb-3">Join a Pool</h2>
        <div className="flex gap-2">
          <input
            type="text"
            value={joinId}
            onChange={(e) => setJoinId(e.target.value)}
            placeholder="Enter Pool Object ID (0x...)"
            className="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-pitch-light"
            onKeyDown={(e) => e.key === "Enter" && handleJoinById()}
          />
          <Button onClick={handleJoinById} disabled={!joinId.trim()}>
            Go
          </Button>
        </div>
      </Card>

      {/* My Pools */}
      {isLoading ? (
        <Spinner message="Loading your pools..." />
      ) : (
        <section>
          <h2 className="text-lg font-bold text-white mb-3">My Pools</h2>
          {allPoolIds.length === 0 ? (
            <EmptyState
              title="No pools yet"
              description="Create a pool or join one using its ID."
            />
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              {allPoolIds.map((poolId) => (
                <PoolCard
                  key={poolId}
                  poolId={poolId}
                  linkTo={`/pool/${poolId}`}
                  badge={createdSet.has(poolId) ? "Admin" : undefined}
                />
              ))}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
