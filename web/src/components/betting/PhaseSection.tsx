import { Match, Phase } from "../../types/match";
import { Outcome } from "../../types/pool";
import { MatchCard } from "./MatchCard";
import { PHASES } from "../../data/phases";

interface PhaseSectionProps {
  phase: Phase;
  matches: Match[];
  bets: number[];
  pendingBets: Map<number, number>;
  results: number[];
  onBetChange: (matchIndex: number, outcome: Outcome) => void;
  disabled?: boolean;
  isKnockout?: boolean;
}

export function PhaseSection({ phase, matches, bets, pendingBets, results, onBetChange, disabled, isKnockout }: PhaseSectionProps) {
  const phaseInfo = PHASES.find((p) => p.phase === phase);

  return (
    <div className="mb-6">
      <h3 className="text-sm font-bold text-gray-300 mb-3 uppercase tracking-wider">
        {phaseInfo?.label ?? "Unknown Phase"}
      </h3>
      <div className="space-y-2">
        {matches.map((match) => (
          <MatchCard
            key={match.matchIndex}
            match={match}
            currentBet={bets[match.matchIndex] as Outcome}
            pendingBet={(pendingBets.get(match.matchIndex) ?? Outcome.None) as Outcome}
            result={results[match.matchIndex] as Outcome}
            onBetChange={onBetChange}
            disabled={disabled}
            isKnockout={isKnockout}
          />
        ))}
      </div>
    </div>
  );
}
