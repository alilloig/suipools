import { Outcome } from "../../types/pool";

interface OutcomeSelectorProps {
  selected: Outcome;
  onSelect: (outcome: Outcome) => void;
  disabled?: boolean;
  existingBet?: Outcome;
  result?: Outcome;
  isKnockout?: boolean;
}

const OUTCOME_LABELS: Record<number, string> = {
  [Outcome.Home]: "H",
  [Outcome.Draw]: "D",
  [Outcome.Away]: "A",
};

const OUTCOME_COLORS: Record<number, { selected: string; default: string }> = {
  [Outcome.Home]: { selected: "bg-green-600 text-white ring-2 ring-green-400", default: "" },
  [Outcome.Draw]: { selected: "bg-yellow-600 text-white ring-2 ring-yellow-400", default: "" },
  [Outcome.Away]: { selected: "bg-blue-600 text-white ring-2 ring-blue-400", default: "" },
};

export function OutcomeSelector({ selected, onSelect, disabled, existingBet, result, isKnockout }: OutcomeSelectorProps) {
  const outcomes = isKnockout
    ? [Outcome.Home, Outcome.Away]
    : [Outcome.Home, Outcome.Draw, Outcome.Away];

  return (
    <div className="flex gap-1">
      {outcomes.map((outcome) => {
        const isSelected = selected === outcome;
        const isExistingBet = existingBet === outcome;
        const isCorrectResult = result !== undefined && result !== Outcome.None && result === outcome;
        const isWrongBet = result !== undefined && result !== Outcome.None && existingBet === outcome && result !== outcome;

        let className = "w-9 h-9 rounded-md text-sm font-bold transition-all ";
        if (isCorrectResult && isExistingBet) {
          className += "bg-green-600 text-white ring-2 ring-green-400";
        } else if (isWrongBet) {
          className += "bg-red-600/50 text-red-300 ring-2 ring-red-400";
        } else if (isExistingBet) {
          className += OUTCOME_COLORS[outcome].selected || "bg-pitch-light text-white";
        } else if (isSelected) {
          className += OUTCOME_COLORS[outcome].selected || "bg-yellow-600 text-white ring-2 ring-yellow-400";
        } else {
          className += "bg-gray-700 text-gray-400 hover:bg-gray-600";
        }

        if (disabled && !isExistingBet) {
          className += " opacity-50 cursor-not-allowed";
        }

        return (
          <button
            key={outcome}
            onClick={() => !disabled && onSelect(outcome)}
            disabled={disabled}
            className={className}
          >
            {OUTCOME_LABELS[outcome]}
          </button>
        );
      })}
    </div>
  );
}
