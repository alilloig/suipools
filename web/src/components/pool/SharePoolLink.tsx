import { useState } from "react";
import { Button } from "../ui/Button";

interface SharePoolLinkProps {
  poolId: string;
}

export function SharePoolLink({ poolId }: SharePoolLinkProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    const url = `${window.location.origin}${window.location.pathname}#/pool/${poolId}`;
    await navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <Button variant="secondary" size="sm" onClick={handleCopy}>
      {copied ? "Copied!" : "Share Link"}
    </Button>
  );
}
