import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { poolTarget, POOL_ENTRY_FUNCTIONS } from "../../../constants/blockchain";
import {
  CreatePoolParams,
  JoinPoolParams,
  PlaceBetsParams,
  FinalizeParams,
  ClaimPrizeParams,
  WithdrawRemainderParams,
} from "../../../types/sui";

const SUI_COIN_TYPE = "0x2::coin::Coin<0x2::sui::SUI>";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function optionSome(tx: Transaction, value: any) {
  return tx.moveCall({
    target: "0x1::option::some",
    typeArguments: [SUI_COIN_TYPE],
    arguments: [value],
  });
}

function optionNone(tx: Transaction) {
  return tx.moveCall({
    target: "0x1::option::none",
    typeArguments: [SUI_COIN_TYPE],
    arguments: [],
  });
}

export function buildCreatePoolTx(params: CreatePoolParams & { sender: string }): Transaction {
  const tx = new Transaction();

  const entryFee = params.entryFee;

  let feeCoinOption;
  if (entryFee > 0n) {
    const [coin] = tx.splitCoins(tx.gas, [tx.pure.u64(entryFee)]);
    feeCoinOption = optionSome(tx, coin);
  } else {
    feeCoinOption = optionNone(tx);
  }

  const cap = tx.moveCall({
    target: poolTarget(POOL_ENTRY_FUNCTIONS.create),
    arguments: [
      tx.pure.u64(entryFee),
      tx.pure(bcs.vector(bcs.U64).serialize(params.prizeBps)),
      feeCoinOption,
    ],
  });

  tx.transferObjects([cap], tx.pure.address(params.sender));

  return tx;
}

export function buildJoinPoolTx(params: JoinPoolParams): Transaction {
  const tx = new Transaction();

  let feeCoinOption;
  if (params.entryFee > 0n) {
    const [coin] = tx.splitCoins(tx.gas, [tx.pure.u64(params.entryFee)]);
    feeCoinOption = optionSome(tx, coin);
  } else {
    feeCoinOption = optionNone(tx);
  }

  tx.moveCall({
    target: poolTarget(POOL_ENTRY_FUNCTIONS.join),
    arguments: [
      tx.object(params.poolId),
      feeCoinOption,
    ],
  });

  return tx;
}

export function buildPlaceBetsTx(params: PlaceBetsParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: poolTarget(POOL_ENTRY_FUNCTIONS.placeBets),
    arguments: [
      tx.object(params.poolId),
      tx.object(params.tournamentId),
      tx.pure(bcs.vector(bcs.U64).serialize(params.matchIndices)),
      tx.pure(bcs.vector(bcs.U8).serialize(params.outcomes)),
      tx.object("0x6"), // Clock
    ],
  });

  return tx;
}

export function buildFinalizeTx(params: FinalizeParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: poolTarget(POOL_ENTRY_FUNCTIONS.finalize),
    arguments: [
      tx.object(params.poolId),
      tx.object(params.capId),
      tx.object(params.tournamentId),
    ],
  });

  return tx;
}

export function buildClaimPrizeTx(params: ClaimPrizeParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: poolTarget(POOL_ENTRY_FUNCTIONS.claimPrize),
    arguments: [
      tx.object(params.poolId),
    ],
  });

  return tx;
}

export function buildWithdrawRemainderTx(params: WithdrawRemainderParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: poolTarget(POOL_ENTRY_FUNCTIONS.withdrawRemainder),
    arguments: [
      tx.object(params.poolId),
      tx.object(params.capId),
    ],
  });

  return tx;
}
