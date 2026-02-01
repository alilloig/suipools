import { useCurrentAccount, useSuiClientQuery } from "@mysten/dapp-kit";
import { squaresCreatorCapType } from "../constants/blockchain";
import {
  extractSquaresCapFields,
  SquaresCapFields,
} from "../utils/parsing/squares";

export function useSquaresCreatorCaps() {
  const account = useCurrentAccount();

  const { data, isLoading, error, refetch } = useSuiClientQuery(
    "getOwnedObjects",
    {
      owner: account?.address!,
      filter: { StructType: squaresCreatorCapType() },
      options: { showContent: true },
    },
    { enabled: !!account?.address },
  );

  const caps: SquaresCapFields[] = (data?.data ?? [])
    .map((obj) => extractSquaresCapFields(obj))
    .filter((c): c is SquaresCapFields => c !== null);

  return { caps, isLoading, error, refetch };
}
