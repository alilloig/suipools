import { ConnectButton } from "@mysten/dapp-kit";

export function ConnectPrompt({ message }: { message?: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-12 gap-4">
      <p className="text-gray-400">
        {message ?? "Connect your wallet to continue"}
      </p>
      <ConnectButton />
    </div>
  );
}
