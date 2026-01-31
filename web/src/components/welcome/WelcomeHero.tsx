import { ConnectButton } from "@mysten/dapp-kit";

interface WelcomeHeroProps {
  variant?: "full" | "compact";
}

export function WelcomeHero({ variant = "full" }: WelcomeHeroProps) {
  if (variant === "compact") {
    return <CompactHero />;
  }

  return <FullHero />;
}

/* ── Full variant (HomePage) ─────────────────────────────── */

function FullHero() {
  return (
    <div className="relative overflow-hidden rounded-2xl isolate">
      {/* Background layers */}
      <div className="absolute inset-0 bg-gradient-to-b from-gray-900 via-pitch-dark to-gray-900" />
      <div className="absolute inset-0 welcome-hero-pitch-lines animate-pitch-lines" />
      <div className="absolute inset-0 welcome-hero-floodlight animate-glow-pulse" />
      <div className="absolute inset-0 welcome-hero-grain" />

      {/* Decorative soccer ball */}
      <div
        className="absolute -top-6 -right-6 w-28 h-28 rounded-full border-2 border-gold/20 opacity-20"
        style={{
          boxShadow: "0 0 40px rgba(212,175,55,0.15), inset 0 0 30px rgba(212,175,55,0.05)",
        }}
      />

      {/* Content */}
      <div className="relative z-10 px-6 py-14 sm:px-10 sm:py-20 text-center space-y-8">
        {/* Brand */}
        <div className="animate-fade-in">
          <h1 className="font-display font-bold text-5xl sm:text-7xl tracking-wide text-gold uppercase">
            SuiPools
          </h1>
        </div>

        {/* Tagline */}
        <p
          className="font-display text-xl sm:text-2xl text-white tracking-wider opacity-0 animate-fade-in-up"
          style={{ animationDelay: "0.15s" }}
        >
          Predict. Compete. Win On-Chain.
        </p>

        {/* Subtitle */}
        <p
          className="text-gray-400 max-w-lg mx-auto opacity-0 animate-fade-in-up"
          style={{ animationDelay: "0.3s" }}
        >
          Create and join prediction pools for your favorite competitions.
          Invite friends, compete for the top spot, and claim trustless prizes — all on Sui.
        </p>

        {/* CTA */}
        <div
          className="welcome-hero-cta inline-block opacity-0 animate-fade-in-up"
          style={{ animationDelay: "0.45s" }}
        >
          <ConnectButton />
        </div>
      </div>
    </div>
  );
}

/* ── Compact variant (PoolPage) ──────────────────────────── */

function CompactHero() {
  return (
    <div className="relative overflow-hidden rounded-xl isolate">
      {/* Background layers */}
      <div className="absolute inset-0 bg-gradient-to-b from-gray-900 via-pitch-dark to-gray-900" />
      <div className="absolute inset-0 welcome-hero-floodlight opacity-60" />
      <div className="absolute inset-0 welcome-hero-grain" />

      {/* Content */}
      <div className="relative z-10 px-6 py-8 text-center space-y-4">
        <h2 className="font-display font-bold text-2xl sm:text-3xl tracking-wide text-gold uppercase animate-fade-in">
          SuiPools
        </h2>
        <p
          className="font-display text-base text-white/80 tracking-wider opacity-0 animate-fade-in-up"
          style={{ animationDelay: "0.1s" }}
        >
          Predict. Compete. Win On-Chain.
        </p>
        <p
          className="text-gray-400 text-sm max-w-md mx-auto opacity-0 animate-fade-in-up"
          style={{ animationDelay: "0.2s" }}
        >
          Connect your wallet to join this pool and start placing predictions.
        </p>
        <div
          className="welcome-hero-cta inline-block opacity-0 animate-fade-in-up"
          style={{ animationDelay: "0.3s" }}
        >
          <ConnectButton />
        </div>
      </div>
    </div>
  );
}
