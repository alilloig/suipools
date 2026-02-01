import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { useCreateSquaresPool } from "../hooks/useCreateSquaresPool";
import { MIST_PER_SUI } from "../constants/pool";

const QUARTER_PRESETS: { label: string; bps: number[] }[] = [
  { label: "Equal (25% each)", bps: [2500, 2500, 2500, 2500] },
  { label: "Final-heavy (20/20/20/40)", bps: [2000, 2000, 2000, 4000] },
  { label: "Escalating (10/15/25/50)", bps: [1000, 1500, 2500, 5000] },
];

export function CreateSquaresPoolPage() {
  const account = useCurrentAccount();
  const navigate = useNavigate();
  const { createPool, isPending, error: txError } = useCreateSquaresPool();

  const [entryFeeSui, setEntryFeeSui] = useState("0.01");
  const [maxPerPlayer, setMaxPerPlayer] = useState(10);
  const [presetIdx, setPresetIdx] = useState(1);
  const [error, setError] = useState<string | null>(null);

  if (!account) {
    return (
      <ConnectPrompt message="Connect your wallet to create a Super Bowl Squares pool" />
    );
  }

  const prizeBps = QUARTER_PRESETS[presetIdx].bps;

  const handleSubmit = async () => {
    setError(null);
    const feeParsed = parseFloat(entryFeeSui);
    if (isNaN(feeParsed) || feeParsed < 0) {
      setError("Invalid entry fee");
      return;
    }
    const entryFee = BigInt(Math.round(feeParsed * Number(MIST_PER_SUI)));

    try {
      await createPool(entryFee, maxPerPlayer, prizeBps);
      navigate("/super-bowl-squares");
    } catch (err) {
      console.error("Failed to create pool:", err);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-white mb-6">
        Create Super Bowl Squares Pool
      </h1>

      <Card>
        <div className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Entry Fee per Square (SUI)
            </label>
            <input
              type="number"
              min="0"
              step="0.01"
              value={entryFeeSui}
              onChange={(e) => setEntryFeeSui(e.target.value)}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-pitch-light"
            />
            <p className="text-xs text-gray-500 mt-1">
              Total prize pool = fee x 100 squares
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Max Squares per Player
            </label>
            <select
              value={maxPerPlayer}
              onChange={(e) => setMaxPerPlayer(Number(e.target.value))}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-pitch-light"
            >
              {[1, 2, 5, 10, 20, 25, 50, 100].map((n) => (
                <option key={n} value={n}>
                  {n} {n === 1 ? "square" : "squares"}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-3">
              Quarterly Prize Split
            </label>
            <div className="space-y-2">
              {QUARTER_PRESETS.map((p, idx) => (
                <button
                  key={idx}
                  onClick={() => setPresetIdx(idx)}
                  className={`w-full p-3 rounded-lg border text-left transition-all ${
                    presetIdx === idx
                      ? "border-pitch-light bg-pitch-light/10 ring-2 ring-pitch-light"
                      : "border-gray-600 bg-gray-700/50 hover:border-gray-500"
                  }`}
                >
                  <p className="text-sm font-bold text-white">{p.label}</p>
                  <p className="text-xs text-gray-400 mt-1">
                    Q1: {p.bps[0] / 100}% / Q2: {p.bps[1] / 100}% / Q3:{" "}
                    {p.bps[2] / 100}% / Final: {p.bps[3] / 100}%
                  </p>
                </button>
              ))}
            </div>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-300 mb-2">
              Prize Preview
            </h3>
            <div className="bg-gray-700/50 rounded-lg p-3 space-y-1">
              {["Q1", "Q2", "Q3", "Final"].map((label, idx) => (
                <div key={idx} className="flex justify-between text-sm">
                  <span className="text-gray-400">{label}</span>
                  <span className="text-white font-medium">
                    {(prizeBps[idx] / 100).toFixed(0)}%
                  </span>
                </div>
              ))}
            </div>
          </div>

          {error && <ErrorMessage message={error} />}
          {txError && <ErrorMessage message={String(txError)} />}

          <Button
            onClick={handleSubmit}
            loading={isPending}
            size="lg"
            className="w-full"
          >
            Create Pool
          </Button>
        </div>
      </Card>
    </div>
  );
}
