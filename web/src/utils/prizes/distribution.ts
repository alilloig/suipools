export type PrizePreset = "steep" | "balanced" | "flat";

/**
 * Generate prize distribution basis points for top N winners.
 * Returns a non-increasing array of numbers summing to 10000.
 */
export function generatePrizeBps(topN: number, preset: PrizePreset): number[] {
  if (topN < 1) throw new Error("topN must be >= 1");
  if (topN === 1) return [10000];

  switch (preset) {
    case "steep":
      return steepDistribution(topN);
    case "balanced":
      return balancedDistribution(topN);
    case "flat":
      return flatDistribution(topN);
  }
}

/** Winner takes a large share, drops off steeply. */
function steepDistribution(n: number): number[] {
  // Weights: 1st gets n, 2nd gets n-1, etc. (reversed for non-increasing)
  const weights = Array.from({ length: n }, (_, i) => n - i);
  const totalWeight = weights.reduce((a, b) => a + b, 0);

  const bps = weights.map((w) => Math.floor((w / totalWeight) * 10000));

  // Distribute any remainder to first place
  const sum = bps.reduce((a, b) => a + b, 0);
  bps[0] += 10000 - sum;

  return bps;
}

/** More even distribution with moderate top-weighting. */
function balancedDistribution(n: number): number[] {
  // Weights: sqrt-based to flatten the curve
  const weights = Array.from({ length: n }, (_, i) => Math.sqrt(n - i));
  const totalWeight = weights.reduce((a, b) => a + b, 0);

  const bps = weights.map((w) => Math.floor((w / totalWeight) * 10000));

  const sum = bps.reduce((a, b) => a + b, 0);
  bps[0] += 10000 - sum;

  return bps;
}

/** Nearly equal distribution. */
function flatDistribution(n: number): number[] {
  const base = Math.floor(10000 / n);
  const bps = Array.from({ length: n }, () => base);

  // Give remainder to first places
  let remainder = 10000 - base * n;
  for (let i = 0; i < remainder; i++) {
    bps[i] += 1;
  }

  return bps;
}
