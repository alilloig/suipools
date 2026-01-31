import { TOTAL_MATCHES } from "../../constants/pool";

interface ResultsProgressProps {
  resultsEntered: number;
}

export function ResultsProgress({ resultsEntered }: ResultsProgressProps) {
  const pct = Math.round((resultsEntered / TOTAL_MATCHES) * 100);

  return (
    <div className="mb-6">
      <div className="flex items-center justify-between text-sm mb-2">
        <span className="text-gray-400">Results Entered</span>
        <span className="text-white font-medium">
          {resultsEntered}/{TOTAL_MATCHES} ({pct}%)
        </span>
      </div>
      <div className="w-full bg-gray-700 rounded-full h-2.5">
        <div
          className="bg-pitch-light h-2.5 rounded-full transition-all"
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}
