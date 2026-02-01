import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { squaresTarget, SQUARES_ENTRY_FUNCTIONS } from "../../../constants/blockchain";
import {
  CreateSquaresPoolParams,
  BuySquareParams,
  AssignNumbersParams,
  EnterScoreParams,
  ClaimSquaresPrizeParams,
  WithdrawSquaresRemainderParams,
} from "../../../types/sui";

// Random object on Sui (always 0x8)
const SUI_RANDOM_OBJECT = "0x8";

export function buildCreateSquaresPoolTx(
  params: CreateSquaresPoolParams & { sender: string },
): Transaction {
  const tx = new Transaction();

  const cap = tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.create),
    arguments: [
      tx.pure.u64(params.entryFee),
      tx.pure.u64(params.maxPerPlayer),
      tx.pure(bcs.vector(bcs.U64).serialize(params.prizeBps)),
    ],
  });

  tx.transferObjects([cap], tx.pure.address(params.sender));
  return tx;
}

export function buildBuySquareTx(params: BuySquareParams): Transaction {
  const tx = new Transaction();

  const [coin] = tx.splitCoins(tx.gas, [tx.pure.u64(params.entryFee)]);

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.buySquare),
    arguments: [
      tx.object(params.poolId),
      tx.pure.u64(params.position),
      coin,
    ],
  });

  return tx;
}

export function buildAssignNumbersTx(params: AssignNumbersParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.assignNumbers),
    arguments: [
      tx.object(params.poolId),
      tx.object(SUI_RANDOM_OBJECT),
    ],
  });

  return tx;
}

export function buildEnterScoreTx(params: EnterScoreParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.enterScore),
    arguments: [
      tx.object(params.poolId),
      tx.object(params.capId),
      tx.pure.u64(params.quarter),
      tx.pure.u64(params.teamAScore),
      tx.pure.u64(params.teamBScore),
    ],
  });

  return tx;
}

export function buildClaimSquaresPrizeTx(params: ClaimSquaresPrizeParams): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.claimPrize),
    arguments: [
      tx.object(params.poolId),
      tx.pure.u64(params.quarter),
    ],
  });

  return tx;
}

export function buildWithdrawSquaresRemainderTx(
  params: WithdrawSquaresRemainderParams,
): Transaction {
  const tx = new Transaction();

  tx.moveCall({
    target: squaresTarget(SQUARES_ENTRY_FUNCTIONS.withdrawRemainder),
    arguments: [
      tx.object(params.poolId),
      tx.object(params.capId),
    ],
  });

  return tx;
}
