export function truncateAddress(address: string): string {
  if (address.length <= 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function getExplorerUrl(objectId: string, type: "object" | "txblock" | "address" = "object"): string {
  return `https://suiscan.xyz/testnet/${type}/${objectId}`;
}
