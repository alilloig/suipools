import { useState } from "react";
import { Button } from "../ui/Button";

interface SquaresGridProps {
  grid: (string | null)[];
  rowNumbers: number[];
  colNumbers: number[];
  currentAccount: string | undefined;
  quarterlyWinners: (string | null)[];
  onBuySquare: (position: number) => Promise<void>;
  isBuying: boolean;
  entryFee: string;
}

export function SquaresGrid({
  grid,
  rowNumbers,
  colNumbers,
  currentAccount,
  quarterlyWinners,
  onBuySquare,
  isBuying,
  entryFee,
}: SquaresGridProps) {
  const [selected, setSelected] = useState<number | null>(null);
  const numbersAssigned = rowNumbers.length > 0;
  const gridFull = grid.every((cell) => cell !== null);

  const winningPositions = new Set<number>();
  if (numbersAssigned) {
    quarterlyWinners.forEach((winner) => {
      if (winner) {
        grid.forEach((cell, idx) => {
          if (cell === winner) winningPositions.add(idx);
        });
      }
    });
  }

  const handleClick = (position: number) => {
    if (grid[position] !== null || gridFull || !currentAccount) return;
    setSelected(position === selected ? null : position);
  };

  const handleBuy = async () => {
    if (selected === null) return;
    await onBuySquare(selected);
    setSelected(null);
  };

  const feeSui = (Number(entryFee) / 1_000_000_000).toFixed(2);

  return (
    <div>
      {numbersAssigned && (
        <div
          className="grid gap-1 mb-1 ml-8"
          style={{ gridTemplateColumns: "repeat(10, 1fr)" }}
        >
          {colNumbers.map((n, i) => (
            <div
              key={i}
              className="text-center text-xs font-bold text-gray-400"
            >
              {n}
            </div>
          ))}
        </div>
      )}

      <div className="flex">
        {numbersAssigned && (
          <div className="flex flex-col gap-1 mr-1 justify-center">
            {rowNumbers.map((n, i) => (
              <div
                key={i}
                className="w-7 h-7 flex items-center justify-center text-xs font-bold text-gray-400"
              >
                {n}
              </div>
            ))}
          </div>
        )}

        <div
          className="grid gap-1 flex-1"
          style={{ gridTemplateColumns: "repeat(10, 1fr)" }}
        >
          {grid.map((cell, idx) => {
            const isOwned = cell !== null;
            const isMine = cell === currentAccount;
            const isAvailable = !isOwned && !gridFull && !!currentAccount;
            const isSelected = selected === idx;

            return (
              <button
                key={idx}
                onClick={() => handleClick(idx)}
                className={`aspect-square rounded text-[10px] font-bold transition-all ${
                  isMine
                    ? "bg-pitch-light text-white"
                    : isOwned
                      ? "bg-gray-600 text-gray-400"
                      : isAvailable
                        ? "bg-gray-700 text-gray-500 hover:bg-gray-600 cursor-pointer"
                        : "bg-gray-800 text-gray-700"
                } ${isSelected ? "ring-2 ring-yellow-400 scale-110" : ""}`}
                disabled={!isAvailable}
              >
                {isMine ? "ME" : isOwned ? "X" : ""}
              </button>
            );
          })}
        </div>
      </div>

      <p className="text-sm text-gray-400 mt-3">
        {grid.filter((c) => c !== null).length}/100 squares claimed
        {!numbersAssigned && gridFull && " — ready to assign numbers!"}
      </p>

      {selected !== null && (
        <div className="mt-3 p-3 bg-gray-700/50 rounded-lg">
          <p className="text-sm text-gray-300 mb-2">
            Square #{selected} (row {Math.floor(selected / 10)}, col{" "}
            {selected % 10})
          </p>
          <Button
            onClick={handleBuy}
            loading={isBuying}
            disabled={isBuying}
            size="sm"
            className="w-full"
          >
            Buy Square ({feeSui} SUI)
          </Button>
        </div>
      )}
    </div>
  );
}
