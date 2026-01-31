import { useCurrentAccount, useSuiClientQuery } from "@mysten/dapp-kit";
import { poolCreatorCapType } from "../constants/blockchain";
import { extractCapFields, CapFields } from "../utils/parsing/pool";

export function usePoolCreatorCaps() {
  const account = useCurrentAccount();

  const { data, isLoading, error, refetch } = useSuiClientQuery(
    "getOwnedObjects",
    {
      owner: account?.address!,
      filter: {
        StructType: poolCreatorCapType(),
      },
      options: {
        showContent: true,
      },
    },
    {
      enabled: !!account?.address,
    },
  );

  const caps: CapFields[] = (data?.data ?? [])
    .map((obj) => extractCapFields(obj))
    .filter((c): c is CapFields => c !== null);

  return { caps, isLoading, error, refetch };
}
