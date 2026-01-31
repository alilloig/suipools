import { useState, useCallback } from "react";
import { Tabs } from "../ui/Tabs";
import { GroupSection } from "./GroupSection";
import { PhaseSection } from "./PhaseSection";
import { BetSummary } from "./BetSummary";
import { DeadlineCountdown } from "./DeadlineCountdown";
import { Outcome } from "../../types/pool";
import { Phase } from "../../types/match";
import { GROUP_IDS } from "../../data/groups";
import { SCHEDULE } from "../../data/schedule";
import { PHASES } from "../../data/phases";
import { PHASE_DEADLINES } from "../../constants/deadlines";
import { usePlaceBets } from "../../hooks/usePlaceBets";

interface BettingViewProps {
  poolId: string;
  bets: number[];
  results: number[];
  currentPhase: number;
  onBetsPlaced?: () => void;
}

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

const TAB_TO_PHASE_INDEX: Record<string, number> = {
  groups: 0,
  r32: 1,
  r16: 2,
  qf: 3,
  sf: 4,
  third: 5,
  final: 6,
};

export function BettingView({ poolId, bets, results, currentPhase, onBetsPlaced }: BettingViewProps) {
  const [activeTab, setActiveTab] = useState("groups");
  const [pendingBets, setPendingBets] = useState<Map<number, number>>(new Map());
  const { placeBets, isPending } = usePlaceBets();

  const handleBetChange = useCallback((matchIndex: number, outcome: Outcome) => {
    setPendingBets((prev) => {
      const next = new Map(prev);
      if (outcome === Outcome.None) {
        next.delete(matchIndex);
      } else {
        next.set(matchIndex, outcome);
      }
      return next;
    });
  }, []);

  const handleSubmit = async () => {
    if (pendingBets.size === 0) return;
    const matchIndices = Array.from(pendingBets.keys());
    const outcomes = Array.from(pendingBets.values());

    try {
      await placeBets(poolId, matchIndices, outcomes);
      setPendingBets(new Map());
      onBetsPlaced?.();
    } catch (err) {
      console.error("Failed to place bets:", err);
    }
  };

  const activePhaseIndex = TAB_TO_PHASE_INDEX[activeTab] ?? 0;
  const phaseOpen = activePhaseIndex <= currentPhase;
  const deadlineMs = BigInt(PHASE_DEADLINES[activePhaseIndex] ?? 0);

  return (
    <div>
      <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
        <Tabs tabs={TABS} activeTab={activeTab} onTabChange={setActiveTab} />
        {deadlineMs > 0n && <DeadlineCountdown deadlineMs={deadlineMs} />}
      </div>

      {!phaseOpen && (
        <div className="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4 mb-4 text-sm text-yellow-300">
          This phase is not yet open for betting. The tournament admin must advance the phase first.
        </div>
      )}

      <div className="pb-20">
        {activeTab === "groups" ? (
          GROUP_IDS.map((groupId) => {
            const groupMatches = SCHEDULE.filter((m) => m.group === groupId);
            return (
              <GroupSection
                key={groupId}
                groupId={groupId}
                matches={groupMatches}
                bets={bets}
                pendingBets={pendingBets}
                results={results}
                onBetChange={handleBetChange}
                disabled={!phaseOpen}
              />
            );
          })
        ) : (
          (() => {
            const phase = TAB_TO_PHASE[activeTab];
            if (phase === undefined) return null;
            const phaseInfo = PHASES.find((p) => p.phase === phase);
            if (!phaseInfo) return null;
            const phaseMatches = SCHEDULE.filter(
              (m) => m.matchIndex >= phaseInfo.matchStart && m.matchIndex < phaseInfo.matchEnd,
            );
            return (
              <PhaseSection
                phase={phase}
                matches={phaseMatches}
                bets={bets}
                pendingBets={pendingBets}
                results={results}
                onBetChange={handleBetChange}
                isKnockout
                disabled={!phaseOpen}
              />
            );
          })()
        )}
      </div>

      <BetSummary
        pendingCount={pendingBets.size}
        onSubmit={handleSubmit}
        isPending={isPending}
      />
    </div>
  );
}
