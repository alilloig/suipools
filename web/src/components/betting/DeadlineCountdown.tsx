import { useState, useEffect } from "react";
import { Badge } from "../ui/Badge";

interface DeadlineCountdownProps {
  deadlineMs: bigint;
}

export function DeadlineCountdown({ deadlineMs }: DeadlineCountdownProps) {
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    const interval = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(interval);
  }, []);

  const remaining = Number(deadlineMs) - now;
  if (remaining <= 0) {
    return <Badge variant="error">Deadline passed</Badge>;
  }

  const days = Math.floor(remaining / 86_400_000);
  const hours = Math.floor((remaining % 86_400_000) / 3_600_000);
  const minutes = Math.floor((remaining % 3_600_000) / 60_000);

  let text: string;
  if (days > 0) {
    text = `${days}d ${hours}h left`;
  } else if (hours > 0) {
    text = `${hours}h ${minutes}m left`;
  } else {
    text = `${minutes}m left`;
  }

  const variant = days > 1 ? "info" : days > 0 ? "warning" : "error";
  return <Badge variant={variant}>{text}</Badge>;
}
