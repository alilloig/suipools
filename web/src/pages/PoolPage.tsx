import { useParams } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Spinner } from "../components/ui/Spinner";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { PoolHeader } from "../components/pool/PoolHeader";
import { PoolStats } from "../components/pool/PoolStats";
import { JoinPoolButton } from "../components/pool/JoinPoolButton";
import { SharePoolLink } from "../components/pool/SharePoolLink";
import { BettingView } from "../components/betting/BettingView";
import { LeaderboardTable } from "../components/leaderboard/LeaderboardTable";
import { ClaimPrizeButton } from "../components/prizes/ClaimPrizeButton";
import { PrizeBreakdown } from "../components/prizes/PrizeBreakdown";
import { FinalizeButton } from "../components/results/FinalizeButton";
import { WithdrawButton } from "../components/prizes/WithdrawButton";
import { WelcomeHero } from "../components/welcome/WelcomeHero";
import { usePool } from "../hooks/usePool";
import { useIsPoolCreator } from "../hooks/useIsPoolCreator";
import { useParticipantData } from "../hooks/useParticipantData";
import { useTournament } from "../hooks/useTournament";
import { TOTAL_MATCHES } from "../constants/pool";

export function PoolPage() {
  const { poolId } = useParams<{ poolId: string }>();
  const account = useCurrentAccount();
  const { poolFields, isLoading, error, refetch } = usePool(poolId);
  const { isCreator, capId } = useIsPoolCreator(poolId);
  const { data: participantData, refetch: refetchParticipant } = useParticipantData(poolId);
  const { tournamentFields } = useTournament();

  if (!poolId) return <ErrorMessage message="Missing pool ID" />;
  if (isLoading) return <Spinner message="Loading pool..." />;
  if (error) return <ErrorMessage message={String(error)} onRetry={refetch} />;
  if (!poolFields) return <ErrorMessage message="Pool not found" />;

  const isParticipant = account
    ? poolFields.participants.includes(account.address)
    : false;

  const tournamentResultsEntered = tournamentFields ? Number(tournamentFields.resultsEntered) : 0;
  const allTournamentResults = tournamentResultsEntered >= TOTAL_MATCHES;

  const leaderboardEntries = poolFields.finalized
    ? poolFields.participants.map((addr) => ({
        participant: addr,
        points: 0,
      }))
    : [];

  // Bet progress for participant
  const betsPlaced = participantData
    ? participantData.bets.filter((b) => b !== 0).length
    : 0;

  return (
    <div>
      <PoolHeader poolFields={poolFields} poolId={poolId} />

      <div className="flex items-center gap-3 mb-6 flex-wrap">
        <SharePoolLink poolId={poolId} />
        <JoinPoolButton
          poolId={poolId}
          entryFee={poolFields.entryFee}
          participants={poolFields.participants}
          finalized={poolFields.finalized}
          onJoined={refetch}
        />
      </div>

      <PoolStats poolFields={poolFields} />

      {/* Bet progress bar for participants */}
      {isParticipant && !poolFields.finalized && (
        <div className="mb-6">
          <div className="flex justify-between text-sm text-gray-400 mb-1">
            <span>Bets placed</span>
            <span>{betsPlaced}/{TOTAL_MATCHES}</span>
          </div>
          <div className="w-full bg-gray-700 rounded-full h-2">
            <div
              className="bg-pitch-light h-2 rounded-full transition-all"
              style={{ width: `${(betsPlaced / TOTAL_MATCHES) * 100}%` }}
            />
          </div>
        </div>
      )}

      {/* Creator actions: Finalize and Withdraw */}
      {isCreator && capId && !poolFields.finalized && allTournamentResults && (
        <div className="flex justify-center mb-6">
          <FinalizeButton
            poolId={poolId}
            capId={capId}
            resultsEntered={tournamentResultsEntered}
            finalized={poolFields.finalized}
            onFinalized={() => { refetch(); refetchParticipant(); }}
          />
        </div>
      )}
      {isCreator && capId && poolFields.finalized && (
        <div className="flex justify-center mb-6">
          <WithdrawButton poolId={poolId} capId={capId} onWithdrawn={refetch} />
        </div>
      )}

      {/* Finalized: show leaderboard and prizes */}
      {poolFields.finalized && (
        <div className="space-y-6">
          <LeaderboardTable entries={leaderboardEntries} />
          <PrizeBreakdown
            prizeBps={poolFields.prizeBps}
            prizePoolValue={BigInt(poolFields.prizePoolValue)}
            participantCount={poolFields.participants.length}
          />
          {participantData && participantData.prizeAmount > 0n && (
            <ClaimPrizeButton
              poolId={poolId}
              prizeAmount={participantData.prizeAmount}
              claimed={participantData.claimed}
              onClaimed={() => { refetch(); refetchParticipant(); }}
            />
          )}
        </div>
      )}

      {/* Active: show betting view for participants */}
      {!poolFields.finalized && isParticipant && participantData && tournamentFields && (
        <BettingView
          poolId={poolId}
          bets={participantData.bets}
          results={tournamentFields.results}
          currentPhase={tournamentFields.currentPhase}
          onBetsPlaced={() => { refetch(); refetchParticipant(); }}
        />
      )}

      {/* Not connected */}
      {!account && !poolFields.finalized && (
        <WelcomeHero variant="compact" />
      )}
    </div>
  );
}
