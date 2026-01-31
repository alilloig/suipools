import { useState, useCallback } from "react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { Spinner } from "../components/ui/Spinner";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { Tabs } from "../components/ui/Tabs";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { ResultMatchCard } from "../components/results/ResultMatchCard";
import { ResultsProgress } from "../components/results/ResultsProgress";
import { useAdminCap } from "../hooks/useAdminCap";
import { useTournament } from "../hooks/useTournament";
import { useEnterTournamentResults } from "../hooks/useEnterTournamentResults";
import { useAdvancePhase } from "../hooks/useAdvancePhase";
import { Outcome } from "../types/pool";
import { Phase } from "../types/match";
import { GROUP_IDS } from "../data/groups";
import { SCHEDULE } from "../data/schedule";
import { PHASES } from "../data/phases";
import { TOTAL_MATCHES } from "../constants/pool";

const PHASE_LABELS: Record<number, string> = {
  0: "Group Stage",
  1: "Round of 32",
  2: "Round of 16",
  3: "Quarter Finals",
  4: "Semi Finals",
  5: "3rd Place",
  6: "Final",
};

const TABS = [
  { key: "groups", label: "Groups" },
  { key: "r32", label: "R32" },
  { key: "r16", label: "R16" },
  { key: "qf", label: "QF" },
  { key: "sf", label: "SF" },
  { key: "third", label: "3rd" },
  { key: "final", label: "Final" },
];

const TAB_TO_PHASE: Record<string, Phase> = {
  r32: Phase.R32,
  r16: Phase.R16,
  qf: Phase.QF,
  sf: Phase.SF,
  third: Phase.Third,
  final: Phase.Final,
};

export function AdminPage() {
  const account = useCurrentAccount();
  const { adminCapId, isAdmin, isLoading: adminLoading } = useAdminCap();
  const { tournamentFields, isLoading: tournamentLoading, refetch: refetchTournament } = useTournament();
  const { enterResults, isPending: enterPending } = useEnterTournamentResults();
  const { advancePhase, isPending: advancePending } = useAdvancePhase();

  const [activeTab, setActiveTab] = useState("groups");
  const [pendingResults, setPendingResults] = useState<Map<number, number>>(new Map());

  const handleResultChange = useCallback((matchIndex: number, outcome: Outcome) => {
    setPendingResults((prev) => {
      const next = new Map(prev);
      if (outcome === Outcome.None) {
        next.delete(matchIndex);
      } else {
        next.set(matchIndex, outcome);
      }
      return next;
    });
  }, []);

  const handleSubmitResults = async () => {
    if (pendingResults.size === 0 || !adminCapId) return;
    const matchIndices = Array.from(pendingResults.keys());
    const outcomes = Array.from(pendingResults.values());

    try {
      await enterResults(adminCapId, matchIndices, outcomes);
      setPendingResults(new Map());
      refetchTournament();
    } catch (err) {
      console.error("Failed to enter results:", err);
    }
  };

  const handleAdvancePhase = async () => {
    if (!adminCapId) return;
    try {
      await advancePhase(adminCapId);
      refetchTournament();
    } catch (err) {
      console.error("Failed to advance phase:", err);
    }
  };

  if (!account) {
    return <ConnectPrompt message="Connect your admin wallet to manage the tournament" />;
  }

  if (adminLoading || tournamentLoading) {
    return <Spinner message="Loading admin panel..." />;
  }

  if (!isAdmin) {
    return <ErrorMessage message="You do not have admin access. Only the AdminCap holder can manage the tournament." />;
  }

  if (!tournamentFields) {
    return <ErrorMessage message="Tournament not found" />;
  }

  const results = tournamentFields.results;
  const resultsEntered = Number(tournamentFields.resultsEntered);
  const currentPhase = tournamentFields.currentPhase;

  // Check if current phase is complete (all its matches have results)
  const phaseInfo = PHASES[currentPhase];
  let currentPhaseComplete = true;
  if (phaseInfo) {
    for (let i = phaseInfo.matchStart; i < phaseInfo.matchEnd; i++) {
      if (results[i] === 0) {
        currentPhaseComplete = false;
        break;
      }
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-white mb-6">Tournament Admin</h1>

      {/* Tournament Status */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
        <Card className="!p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide">Phase</p>
          <p className="text-lg font-bold text-white mt-1">{PHASE_LABELS[currentPhase]}</p>
        </Card>
        <Card className="!p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide">Results</p>
          <p className="text-lg font-bold text-white mt-1">{resultsEntered}/{TOTAL_MATCHES}</p>
        </Card>
        <Card className="!p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide">Groups Done</p>
          <p className="text-lg font-bold text-white mt-1">{tournamentFields.groupPhaseComplete ? "Yes" : "No"}</p>
        </Card>
        <Card className="!p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide">Phase Complete</p>
          <p className="text-lg font-bold text-white mt-1">{currentPhaseComplete ? "Yes" : "No"}</p>
        </Card>
      </div>

      {/* Advance Phase Button */}
      {currentPhaseComplete && currentPhase < 6 && (
        <div className="flex justify-center mb-6">
          <Button
            onClick={handleAdvancePhase}
            loading={advancePending}
            size="lg"
          >
            Advance to {PHASE_LABELS[currentPhase + 1]}
          </Button>
        </div>
      )}

      {/* Results Entry */}
      <ResultsProgress resultsEntered={resultsEntered} />

      <Tabs tabs={TABS} activeTab={activeTab} onTabChange={setActiveTab} />

      <div className="mt-4 space-y-2">
        {activeTab === "groups" ? (
          GROUP_IDS.map((groupId) => {
            const groupMatches = SCHEDULE.filter((m) => m.group === groupId);
            return (
              <div key={groupId} className="mb-4">
                <h3 className="text-sm font-bold text-gray-300 mb-2 uppercase tracking-wider">
                  Group {groupId}
                </h3>
                <div className="space-y-2">
                  {groupMatches.map((match) => (
                    <ResultMatchCard
                      key={match.matchIndex}
                      match={match}
                      currentResult={results[match.matchIndex] as Outcome}
                      pendingResult={(pendingResults.get(match.matchIndex) ?? Outcome.None) as Outcome}
                      onResultChange={handleResultChange}
                    />
                  ))}
                </div>
              </div>
            );
          })
        ) : (
          (() => {
            const phase = TAB_TO_PHASE[activeTab];
            if (phase === undefined) return null;
            const pInfo = PHASES.find((p) => p.phase === phase);
            if (!pInfo) return null;
            const phaseMatches = SCHEDULE.filter(
              (m) => m.matchIndex >= pInfo.matchStart && m.matchIndex < pInfo.matchEnd,
            );
            return phaseMatches.map((match) => (
              <ResultMatchCard
                key={match.matchIndex}
                match={match}
                currentResult={results[match.matchIndex] as Outcome}
                pendingResult={(pendingResults.get(match.matchIndex) ?? Outcome.None) as Outcome}
                onResultChange={handleResultChange}
              />
            ));
          })()
        )}
      </div>

      {pendingResults.size > 0 && (
        <div className="fixed bottom-0 left-0 right-0 z-30 bg-gray-900/95 border-t border-gray-700 backdrop-blur-sm">
          <div className="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
            <p className="text-sm text-gray-300">
              <span className="font-bold text-white">{pendingResults.size}</span> result{pendingResults.size !== 1 ? "s" : ""} to submit
            </p>
            <Button onClick={handleSubmitResults} loading={enterPending}>
              Submit Results
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
