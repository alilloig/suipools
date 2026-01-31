import { useCurrentAccount } from "@mysten/dapp-kit";
import { WelcomeHero } from "../components/welcome/WelcomeHero";
import { PoolTypeCatalog } from "../components/catalog/PoolTypeCatalog";

export function HomePage() {
  const account = useCurrentAccount();

  return (
    <div className="space-y-8">
      {!account && <WelcomeHero />}
      <PoolTypeCatalog />
    </div>
  );
}
