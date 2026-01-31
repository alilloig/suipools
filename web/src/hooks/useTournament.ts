import { useSuiClientQuery } from "@mysten/dapp-kit";
import { getTournamentId } from "../constants/env";
import { extractTournamentFields, TournamentFields } from "../utils/parsing/pool";

export function useTournament() {
  const tournamentId = getTournamentId();

  const { data, isLoading, error, refetch } = useSuiClientQuery(
    "getObject",
    {
      id: tournamentId,
      options: {
        showContent: true,
      },
    },
    {
      enabled: !!tournamentId,
    },
  );

  const tournamentFields: TournamentFields | null = data ? extractTournamentFields(data) : null;

  return { tournamentFields, isLoading, error, refetch };
}
