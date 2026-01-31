import { Match } from "../../types/match";
import { Outcome } from "../../types/pool";
import { OutcomeSelector } from "./OutcomeSelector";
import { TEAMS } from "../../data/teams";
import { VENUES } from "../../data/venues";
import { formatMatchDate } from "../../utils/formatting/dates";

interface MatchCardProps {
  match: Match;
  currentBet: Outcome;
  pendingBet: Outcome;
  result: Outcome;
  onBetChange: (matchIndex: number, outcome: Outcome) => void;
  disabled?: boolean;
  isKnockout?: boolean;
}

export function MatchCard({ match, currentBet, pendingBet, result, onBetChange, disabled, isKnockout }: MatchCardProps) {
  const homeTeam = TEAMS[match.home];
  const awayTeam = TEAMS[match.away];
  const venue = VENUES[match.venue];

  const selected = pendingBet !== Outcome.None ? pendingBet : currentBet;
  const hasExistingBet = currentBet !== Outcome.None;
  const isDisabled = disabled || hasExistingBet;

  return (
    <div className="flex items-center gap-3 py-3 px-4 bg-gray-800/50 rounded-lg">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 text-sm">
          <span className="font-medium text-white">
            {homeTeam ? `${homeTeam.flag} ${homeTeam.code}` : match.home}
          </span>
          <span className="text-gray-500">vs</span>
          <span className="font-medium text-white">
            {awayTeam ? `${awayTeam.flag} ${awayTeam.code}` : match.away}
          </span>
        </div>
        <div className="text-xs text-gray-500 mt-0.5">
          {formatMatchDate(match.date)}
          {venue && ` — ${venue.name}`}
        </div>
      </div>

      {result !== Outcome.None && (
        <div className="text-xs px-2 py-1 rounded bg-gray-700 text-gray-300">
          {result === Outcome.Home ? "H" : result === Outcome.Draw ? "D" : "A"}
        </div>
      )}

      <OutcomeSelector
        selected={selected}
        onSelect={(outcome) => onBetChange(match.matchIndex, outcome)}
        disabled={isDisabled}
        existingBet={currentBet}
        result={result}
        isKnockout={isKnockout}
      />
    </div>
  );
}
