import { useCurrentAccount, useSuiClientQuery } from "@mysten/dapp-kit";
import { adminCapType } from "../constants/blockchain";

export function useAdminCap() {
  const account = useCurrentAccount();

  const { data, isLoading, error } = useSuiClientQuery(
    "getOwnedObjects",
    {
      owner: account?.address!,
      filter: {
        StructType: adminCapType(),
      },
      options: {
        showContent: true,
      },
    },
    {
      enabled: !!account?.address,
    },
  );

  const adminCapId = data?.data?.[0]?.data?.objectId ?? null;

  return { adminCapId, isAdmin: !!adminCapId, isLoading, error };
}
