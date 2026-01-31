export function formatMatchDate(isoDate: string): string {
  const d = new Date(isoDate);
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatDeadline(timestampMs: bigint): string {
  const d = new Date(Number(timestampMs));
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function isBeforeDeadline(deadlineMs: bigint): boolean {
  return Date.now() < Number(deadlineMs);
}
