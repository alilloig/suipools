import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { Card } from "../components/ui/Card";
import { Button } from "../components/ui/Button";
import { ErrorMessage } from "../components/ui/ErrorMessage";
import { ConnectPrompt } from "../components/wallet/ConnectPrompt";
import { useCreatePool } from "../hooks/useCreatePool";
import { MIST_PER_SUI } from "../constants/pool";
import { generatePrizeBps, PrizePreset } from "../utils/prizes/distribution";

const PRESETS: { key: PrizePreset; label: string; description: string }[] = [
  { key: "steep", label: "Winner Takes Most", description: "Top places get significantly more" },
  { key: "balanced", label: "Balanced", description: "Moderate top-weighting" },
  { key: "flat", label: "Equitable", description: "Nearly equal shares" },
];

export function CreatePoolPage() {
  const account = useCurrentAccount();
  const navigate = useNavigate();
  const { createPool, isPending, error: txError } = useCreatePool();

  const [entryFeeSui, setEntryFeeSui] = useState("0");
  const [topN, setTopN] = useState(3);
  const [preset, setPreset] = useState<PrizePreset>("balanced");
  const [error, setError] = useState<string | null>(null);

  if (!account) {
    return <ConnectPrompt message="Connect your wallet to create a pool" />;
  }

  const prizeBps = generatePrizeBps(topN, preset);

  const handleSubmit = async () => {
    setError(null);

    const feeParsed = parseFloat(entryFeeSui);
    if (isNaN(feeParsed) || feeParsed < 0) {
      setError("Invalid entry fee");
      return;
    }
    const entryFee = BigInt(Math.round(feeParsed * Number(MIST_PER_SUI)));

    try {
      await createPool(entryFee, prizeBps);
      navigate("/world-cup");
    } catch (err) {
      console.error("Failed to create pool:", err);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-white mb-6">Create New Pool</h1>

      <Card>
        <div className="space-y-6">
          {/* Entry Fee */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Entry Fee (SUI)
            </label>
            <input
              type="number"
              min="0"
              step="0.1"
              value={entryFeeSui}
              onChange={(e) => setEntryFeeSui(e.target.value)}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-pitch-light"
              placeholder="0 for free pool"
            />
            <p className="text-xs text-gray-500 mt-1">Set to 0 for a free pool</p>
          </div>

          {/* Top N Winners */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Number of Winners
            </label>
            <select
              value={topN}
              onChange={(e) => setTopN(Number(e.target.value))}
              className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-pitch-light"
            >
              {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => (
                <option key={n} value={n}>
                  Top {n} {n === 1 ? "winner" : "winners"}
                </option>
              ))}
            </select>
          </div>

          {/* Preset Selection */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-3">
              Distribution Preset
            </label>
            <div className="grid grid-cols-3 gap-3">
              {PRESETS.map((p) => (
                <button
                  key={p.key}
                  onClick={() => setPreset(p.key)}
                  className={`p-3 rounded-lg border text-left transition-all ${
                    preset === p.key
                      ? "border-pitch-light bg-pitch-light/10 ring-2 ring-pitch-light"
                      : "border-gray-600 bg-gray-700/50 hover:border-gray-500"
                  }`}
                >
                  <p className="text-sm font-bold text-white">{p.label}</p>
                  <p className="text-xs text-gray-400 mt-1">{p.description}</p>
                </button>
              ))}
            </div>
          </div>

          {/* Prize Preview */}
          <div>
            <h3 className="text-sm font-medium text-gray-300 mb-2">Distribution Preview</h3>
            <div className="bg-gray-700/50 rounded-lg p-3 space-y-1">
              {prizeBps.map((bp, idx) => (
                <div key={idx} className="flex justify-between text-sm">
                  <span className="text-gray-400">
                    {idx + 1}{idx === 0 ? "st" : idx === 1 ? "nd" : idx === 2 ? "rd" : "th"}
                  </span>
                  <span className="text-white font-medium">{(bp / 100).toFixed(1)}%</span>
                </div>
              ))}
            </div>
          </div>

          {/* Errors */}
          {error && <ErrorMessage message={error} />}
          {txError && <ErrorMessage message={String(txError)} />}

          {/* Submit */}
          <Button onClick={handleSubmit} loading={isPending} size="lg" className="w-full">
            Create Pool
          </Button>
        </div>
      </Card>
    </div>
  );
}
