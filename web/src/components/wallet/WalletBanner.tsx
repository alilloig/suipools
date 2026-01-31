import { useCurrentAccount, ConnectButton } from "@mysten/dapp-kit";

export function WalletBanner() {
  const account = useCurrentAccount();

  if (account) return null;

  return (
    <div className="bg-pitch-dark/50 border border-pitch-light/30 rounded-xl p-8 text-center">
      <h2 className="text-xl font-bold text-white mb-2">Welcome to World Cup Pool</h2>
      <p className="text-gray-400 mb-6">
        Connect your Sui wallet to create or join a prediction pool for the 2026 FIFA World Cup.
      </p>
      <ConnectButton />
    </div>
  );
}
