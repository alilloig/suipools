import { useState, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";
import { Spinner } from "../components/ui/Spinner";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { useMySquaresPools } from "../hooks/useMySquaresPools";

export function SuperBowlSquaresPage() {
  const account = useCurrentAccount();
  const { createdPoolIds, boughtPoolIds, isLoading } = useMySquaresPools();
  const navigate = useNavigate();
  const [joinId, setJoinId] = useState("");

  const handleJoinById = () => {
    const id = joinId.trim();
    if (id) navigate(`/super-bowl-squares/pool/${id}`);
  };

  const allPoolIds = useMemo(() => {
    const set = new Set([...createdPoolIds, ...boughtPoolIds]);
    return [...set];
  }, [createdPoolIds, boughtPoolIds]);

  const createdSet = useMemo(() => new Set(createdPoolIds), [createdPoolIds]);

  if (!account) {
    return (
      <ConnectPrompt message="Connect your wallet to manage Super Bowl Squares pools" />
    );
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold text-white">Super Bowl Squares</h1>

      <div className="flex flex-wrap gap-3">
        <Link to="/super-bowl-squares/create">
          <Button size="lg">Create New Pool</Button>
        </Link>
      </div>

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
                <Link
                  key={poolId}
                  to={`/super-bowl-squares/pool/${poolId}`}
                  className="block"
                >
                  <Card className="hover:ring-2 hover:ring-pitch-light transition-all">
                    <p className="text-sm text-gray-400 truncate">{poolId}</p>
                    {createdSet.has(poolId) && (
                      <span className="text-xs bg-pitch-light/20 text-pitch-light px-2 py-0.5 rounded mt-1 inline-block">
                        Admin
                      </span>
                    )}
                  </Card>
                </Link>
              ))}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
