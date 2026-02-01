import { useParams } from "react-router-dom";
import { useCurrentAccount, useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { useQueryClient } from "@tanstack/react-query";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { Spinner } from "../components/ui/Spinner";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { SquaresGrid } from "../components/squares/SquaresGrid";
import { useSquaresPool } from "../hooks/useSquaresPool";
import { useSquaresCreatorCaps } from "../hooks/useSquaresCreatorCaps";
import { useBuySquare } from "../hooks/useBuySquare";
import {
  buildAssignNumbersTx,
  buildEnterScoreTx,
  buildClaimSquaresPrizeTx,
} from "../services/sui/transactions/squares";
import { useState } from "react";

export function SquaresPoolPage() {
  const { poolId } = useParams<{ poolId: string }>();
  const account = useCurrentAccount();
  const queryClient = useQueryClient();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const { poolFields, isLoading, error, refetch } = useSquaresPool(poolId);
  const { caps } = useSquaresCreatorCaps();
  const { buySquare, isPending: isBuying } = useBuySquare();

  const [scoreQuarter, setScoreQuarter] = useState(0);
  const [teamAScore, setTeamAScore] = useState("");
  const [teamBScore, setTeamBScore] = useState("");

  if (!account) return <ConnectPrompt message="Connect your wallet" />;
  if (isLoading) return <Spinner message="Loading pool..." />;
  if (error || !poolFields) return <ErrorMessage message="Pool not found" />;

  const isCreator = caps.some((c) => c.poolId === poolId);
  const capId = caps.find((c) => c.poolId === poolId)?.id;
  const numbersAssigned = poolFields.rowNumbers.length > 0;
  const gridFull = Number(poolFields.squaresClaimed) === 100;

  const handleBuySquare = async (position: number) => {
    await buySquare(poolId!, position, BigInt(poolFields.entryFee));
    refetch();
  };

  const handleAssignNumbers = async () => {
    const tx = buildAssignNumbersTx({ poolId: poolId! });
    await signAndExecute({ transaction: tx });
    await queryClient.invalidateQueries({ queryKey: ["getObject"] });
    refetch();
  };

  const handleEnterScore = async () => {
    if (!capId) return;
    const tx = buildEnterScoreTx({
      poolId: poolId!,
      capId,
      quarter: scoreQuarter,
      teamAScore: parseInt(teamAScore),
      teamBScore: parseInt(teamBScore),
    });
    await signAndExecute({ transaction: tx });
    refetch();
  };

  const handleClaimPrize = async (quarter: number) => {
    const tx = buildClaimSquaresPrizeTx({ poolId: poolId!, quarter });
    await signAndExecute({ transaction: tx });
    refetch();
  };

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-white">Super Bowl Squares</h1>

      <Card>
        <div className="grid grid-cols-3 gap-4 text-center">
          <div>
            <p className="text-xs text-gray-400">Entry Fee</p>
            <p className="text-lg font-bold text-white">
              {(Number(poolFields.entryFee) / 1e9).toFixed(2)} SUI
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-400">Prize Pool</p>
            <p className="text-lg font-bold text-pitch-light">
              {(Number(poolFields.prizePoolValue) / 1e9).toFixed(2)} SUI
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-400">Squares Claimed</p>
            <p className="text-lg font-bold text-white">
              {poolFields.squaresClaimed}/100
            </p>
          </div>
        </div>
      </Card>

      <Card>
        <h2 className="text-lg font-bold text-white mb-4">Grid</h2>
        <SquaresGrid
          grid={poolFields.grid}
          rowNumbers={poolFields.rowNumbers}
          colNumbers={poolFields.colNumbers}
          currentAccount={account.address}
          quarterlyWinners={poolFields.quarterlyWinners}
          onBuySquare={handleBuySquare}
          isBuying={isBuying}
          entryFee={poolFields.entryFee}
        />
      </Card>

      {gridFull && !numbersAssigned && (
        <Card>
          <h2 className="text-lg font-bold text-white mb-2">
            Grid Full — Assign Numbers
          </h2>
          <p className="text-sm text-gray-400 mb-3">
            All 100 squares are claimed. Assign random numbers to rows and
            columns to start the game.
          </p>
          <Button onClick={handleAssignNumbers} size="lg" className="w-full">
            Assign Numbers
          </Button>
        </Card>
      )}

      {numbersAssigned && (
        <Card>
          <h2 className="text-lg font-bold text-white mb-4">
            Quarterly Scores
          </h2>
          <div className="space-y-3">
            {["Q1", "Q2", "Q3", "Final"].map((label, idx) => {
              const score = poolFields.quarterlyScores[idx];
              const winner = poolFields.quarterlyWinners[idx];
              const claimed = poolFields.quarterlyClaimed[idx];
              const isWinner = winner === account.address;
              const bps = poolFields.prizeBps[idx];

              return (
                <div
                  key={idx}
                  className="flex items-center justify-between p-3 bg-gray-700/50 rounded-lg"
                >
                  <div>
                    <span className="text-sm font-bold text-white">
                      {label}
                    </span>
                    <span className="text-xs text-gray-400 ml-2">
                      ({(bps / 100).toFixed(0)}%)
                    </span>
                    {score && (
                      <span className="text-sm text-gray-300 ml-3">
                        {score.teamA} - {score.teamB}
                      </span>
                    )}
                  </div>
                  <div>
                    {claimed ? (
                      <span className="text-xs text-gray-500">Claimed</span>
                    ) : isWinner ? (
                      <Button
                        size="sm"
                        onClick={() => handleClaimPrize(idx)}
                      >
                        Claim Prize
                      </Button>
                    ) : winner ? (
                      <span className="text-xs text-gray-400">
                        Won: {winner.slice(0, 6)}...
                      </span>
                    ) : (
                      <span className="text-xs text-gray-500">Pending</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      )}

      {isCreator && numbersAssigned && (
        <Card>
          <h2 className="text-lg font-bold text-white mb-4">
            Enter Score (Admin)
          </h2>
          <div className="space-y-3">
            <select
              value={scoreQuarter}
              onChange={(e) => setScoreQuarter(Number(e.target.value))}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white"
            >
              {["Q1", "Q2", "Q3", "Final"].map((label, idx) => (
                <option key={idx} value={idx} disabled={poolFields.quarterlyScores[idx] !== null}>
                  {label}
                  {poolFields.quarterlyScores[idx] !== null ? " (entered)" : ""}
                </option>
              ))}
            </select>
            <div className="grid grid-cols-2 gap-3">
              <input
                type="number"
                min="0"
                value={teamAScore}
                onChange={(e) => setTeamAScore(e.target.value)}
                placeholder="Team A score"
                className="bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white"
              />
              <input
                type="number"
                min="0"
                value={teamBScore}
                onChange={(e) => setTeamBScore(e.target.value)}
                placeholder="Team B score"
                className="bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white"
              />
            </div>
            <Button
              onClick={handleEnterScore}
              size="lg"
              className="w-full"
              disabled={!teamAScore || !teamBScore}
            >
              Enter Score
            </Button>
          </div>
        </Card>
      )}
    </div>
  );
}
