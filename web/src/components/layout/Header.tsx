import { ConnectButton } from "@mysten/dapp-kit";
import { Link } from "react-router-dom";
import { useAdminCap } from "../../hooks/useAdminCap";

export function Header() {
  const { isAdmin } = useAdminCap();

  return (
    <header className="bg-gray-900/80 border-b border-gray-700 backdrop-blur-sm sticky top-0 z-40">
      <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link to="/" className="flex items-center gap-2 text-white font-bold text-lg hover:text-pitch-light transition-colors">
            <span>SuiPools</span>
          </Link>
          {isAdmin && (
            <Link to="/admin" className="text-xs font-medium text-yellow-400 hover:text-yellow-300 transition-colors bg-yellow-400/10 px-2 py-1 rounded">
              Admin
            </Link>
          )}
        </div>
        <ConnectButton />
      </div>
    </header>
  );
}
