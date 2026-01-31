import { bcs } from "@mysten/sui/bcs";

export function parseU64(bytes: Uint8Array): bigint {
  return BigInt(bcs.U64.parse(bytes));
}

export function parseBool(bytes: Uint8Array): boolean {
  return bcs.Bool.parse(bytes);
}

export function parseVectorU8(bytes: Uint8Array): number[] {
  return Array.from(bcs.vector(bcs.U8).parse(bytes));
}

export function parseVectorU64(bytes: Uint8Array): bigint[] {
  return bcs.vector(bcs.U64).parse(bytes).map((v: string | number | bigint) => BigInt(v));
}

export function parseVectorAddress(bytes: Uint8Array): string[] {
  return bcs.vector(bcs.Address).parse(bytes);
}
