const MIST_PER_SUI = 1_000_000_000n;

export function formatSui(mist: bigint): string {
  const whole = mist / MIST_PER_SUI;
  const fraction = mist % MIST_PER_SUI;
  if (fraction === 0n) return `${whole} SUI`;
  const fractionStr = fraction.toString().padStart(9, "0").replace(/0+$/, "");
  return `${whole}.${fractionStr} SUI`;
}

export function formatNumber(n: number): string {
  return n.toLocaleString();
}
