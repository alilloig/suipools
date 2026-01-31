import { Match } from "../../types/match";
import { Outcome } from "../../types/pool";
import { OutcomeSelector } from "../betting/OutcomeSelector";
import { TEAMS } from "../../data/teams";
import { formatMatchDate } from "../../utils/formatting/dates";

interface ResultMatchCardProps {
  match: Match;
  currentResult: Outcome;
  pendingResult: Outcome;
  onResultChange: (matchIndex: number, outcome: Outcome) => void;
}

export function ResultMatchCard({ match, currentResult, pendingResult, onResultChange }: ResultMatchCardProps) {
  const homeTeam = TEAMS[match.home];
  const awayTeam = TEAMS[match.away];

  const hasResult = currentResult !== Outcome.None;

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
        <p className="text-xs text-gray-500 mt-0.5">{formatMatchDate(match.date)}</p>
      </div>

      {hasResult ? (
        <div className="text-sm font-bold text-green-400 px-3">
          {currentResult === Outcome.Home ? "Home" : currentResult === Outcome.Draw ? "Draw" : "Away"}
        </div>
      ) : (
        <OutcomeSelector
          selected={pendingResult}
          onSelect={(outcome) => onResultChange(match.matchIndex, outcome)}
          disabled={false}
        />
      )}
    </div>
  );
}
