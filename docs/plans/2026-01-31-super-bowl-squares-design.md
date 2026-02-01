# Super Bowl Squares Pool Type — Design Document

## Overview

Add a **Super Bowl Squares** pool type to SuiPools. Super Bowl Squares is a 10x10 grid game where each cell maps to a pair of score digits (one per team). Winners are determined by the last digit of each team's score at the end of each quarter. It's a game of pure luck — no football knowledge required.

## Game Rules

1. A **10x10 grid** (100 squares) is created with a fixed entry fee per square
2. Players **pick grid positions** by clicking on empty cells and paying the entry fee
3. After all 100 squares are claimed, **row and column numbers (0-9) are randomly assigned** using Sui's native `sui::random` module
4. An admin **enters scores after each quarter** (Q1, Q2, Q3, Final)
5. For each quarter, the contract computes `team_a_score % 10` and `team_b_score % 10`, finds the cell at that (row_digit, col_digit) intersection, and that cell's owner **wins that quarter's prize share**
6. Winners **claim prizes** on-chain

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Grid model | Players pick positions, numbers randomized after | Traditional Super Bowl Squares rules |
| Randomness | `sui::random` module | Trustless, verifiable on-chain randomness |
| Prize model | 4 quarterly prizes | Traditional: winner at Q1, Q2, Q3, Final |
| Squares per player | Creator sets max per player | Prevents one player from dominating while keeping flexibility |
| Contract structure | Single Move module (`squares.move`) | No shared tournament state needed; scoring is trivial (`% 10`) |
| Create page | Separate `CreateSquaresPoolPage.tsx` | Fields differ from World Cup; keeps pool types decoupled |

---

## Move Contract: `squares.move`

### Structs

```move
module sui_pools::squares;

// === Errors ===
const EGridFull: u64 = 0;
const ESquareTaken: u64 = 1;
const EInvalidPosition: u64 = 2;
const EInsufficientPayment: u64 = 3;
const EMaxSquaresReached: u64 = 4;
const EGridNotFull: u64 = 5;
const ENumbersAlreadyAssigned: u64 = 6;
const ENumbersNotAssigned: u64 = 7;
const EInvalidQuarter: u64 = 8;
const EScoreAlreadyEntered: u64 = 9;
const ENotWinner: u64 = 10;
const EAlreadyClaimed: u64 = 11;
const EScoreNotEntered: u64 = 12;

// === Constants ===
const GRID_SIZE: u64 = 100;
const QUARTERS: u64 = 4;

// === Structs ===

public struct SquaresPool has key {
    id: UID,
    // Grid state
    grid: vector<Option<address>>,        // 100 cells: index = row*10 + col
    row_numbers: vector<u8>,              // 10 digits assigned to rows (empty until randomized)
    col_numbers: vector<u8>,              // 10 digits assigned to columns
    squares_claimed: u64,
    // Config
    entry_fee: u64,                       // Cost per square in MIST
    max_per_player: u64,                  // Max squares one player can own
    prize_bps: vector<u64>,               // 4-element: [Q1_bps, Q2_bps, Q3_bps, Final_bps] summing to 10000
    // Player tracking
    player_squares: Table<address, u64>,  // Address -> count of squares owned
    // Financials
    prize_pool: Balance<SUI>,
    // Game state
    quarterly_scores: vector<Option<QuarterScore>>,  // 4 slots
    quarterly_winners: vector<Option<address>>,       // Resolved winners
    quarterly_claimed: vector<bool>,                  // Claim tracking
}

public struct QuarterScore has store, copy, drop {
    team_a: u64,
    team_b: u64,
}

public struct SquaresCreatorCap has key, store {
    id: UID,
    pool_id: ID,
}
```

### Functions

```move
// === Public Functions ===

/// Create a new Super Bowl Squares pool.
/// prize_bps must be a 4-element vector summing to 10000.
public fun create(
    entry_fee: u64,
    max_per_player: u64,
    prize_bps: vector<u64>,
    ctx: &mut TxContext,
): SquaresCreatorCap;

/// Buy a square at the given position (0-99).
/// Requires payment of entry_fee. Position must be unclaimed.
/// Player must not exceed max_per_player limit.
public fun buy_square(
    pool: &mut SquaresPool,
    position: u64,
    fee: Coin<SUI>,
    ctx: &mut TxContext,
);

/// Randomly assign digits 0-9 to rows and columns.
/// Requires all 100 squares to be claimed.
/// Uses sui::random for verifiable on-chain randomness.
public fun assign_numbers(
    pool: &mut SquaresPool,
    random: &Random,
    ctx: &mut TxContext,
);

/// Admin enters the score for a quarter (0=Q1, 1=Q2, 2=Q3, 3=Final).
/// Resolves the winner for that quarter based on last-digit matching.
public fun enter_score(
    pool: &mut SquaresPool,
    _cap: &SquaresCreatorCap,
    quarter: u64,
    team_a_score: u64,
    team_b_score: u64,
);

/// Winner claims their prize for a specific quarter.
public fun claim_prize(
    pool: &mut SquaresPool,
    quarter: u64,
    ctx: &mut TxContext,
);

/// Creator withdraws any remaining dust after all 4 quarters are claimed.
public fun withdraw_remainder(
    pool: &mut SquaresPool,
    _cap: &SquaresCreatorCap,
    ctx: &mut TxContext,
);
```

### Winner Resolution Logic

```
fn resolve_winner(pool, team_a_score, team_b_score) -> address:
    digit_a = team_a_score % 10
    digit_b = team_b_score % 10

    // Find which row index has digit_a
    row_idx = index where row_numbers[row_idx] == digit_a

    // Find which col index has digit_b
    col_idx = index where col_numbers[col_idx] == digit_b

    // Grid position
    position = row_idx * 10 + col_idx

    return grid[position]  // Owner of that cell
```

### Events

```move
public struct PoolCreated has copy, drop { pool_id: ID, entry_fee: u64, max_per_player: u64 }
public struct SquareBought has copy, drop { pool_id: ID, position: u64, buyer: address }
public struct NumbersAssigned has copy, drop { pool_id: ID, row_numbers: vector<u8>, col_numbers: vector<u8> }
public struct ScoreEntered has copy, drop { pool_id: ID, quarter: u64, team_a: u64, team_b: u64, winner: address }
public struct PrizeClaimed has copy, drop { pool_id: ID, quarter: u64, winner: address, amount: u64 }
```

---

## Frontend Changes

### 1. Pool Type Catalog

Add to `web/src/data/poolTypes.ts`:

```typescript
{
  id: "super-bowl-squares",
  title: "Super Bowl Squares",
  icon: "🏈",
  tagline: "Pick your squares, pray for the right digits",
  route: "/super-bowl-squares",
  enabled: true,
}
```

### 2. New Pages

| Page | Route | Purpose |
|------|-------|---------|
| `SuperBowlSquaresPage.tsx` | `/super-bowl-squares` | Landing: user's squares pools, create/join |
| `CreateSquaresPoolPage.tsx` | `/super-bowl-squares/create` | Form: entry fee, max per player, quarterly prize split |
| `SquaresPoolPage.tsx` | `/super-bowl-squares/pool/:poolId` | Main pool view with interactive grid |

### 3. Grid Visualization (SquaresPoolPage)

The main pool page features an interactive 10x10 grid:

**Before numbers assigned:**
- Shows claimed cells (colored) vs empty cells (clickable)
- Click empty cell -> confirm purchase -> transaction
- Show "X of 100 squares claimed" progress
- When grid is full: "Assign Numbers" button

**After numbers assigned:**
- Row and column headers show assigned digits (0-9)
- Grid cells show owner initials or short address
- Highlight winning cells for each entered quarter

**Score display:**
- Show quarterly scores as they're entered
- Highlight active quarter
- Show prize amount per quarter
- Claim button for winners

### 4. Transaction Builders

New file `web/src/services/sui/transactions/squares.ts`:

```typescript
buildCreateSquaresPoolTx(params: { entryFee: number, maxPerPlayer: number, prizeBps: number[], sender: string }): Transaction
buildBuySquareTx(params: { poolId: string, position: number, feeCoin: string }): Transaction
buildAssignNumbersTx(params: { poolId: string }): Transaction
buildEnterScoreTx(params: { poolId: string, capId: string, quarter: number, teamAScore: number, teamBScore: number }): Transaction
buildClaimPrizeTx(params: { poolId: string, quarter: number }): Transaction
buildWithdrawRemainderTx(params: { poolId: string, capId: string }): Transaction
```

### 5. Hooks

```typescript
useCreateSquaresPool()   // Create pool + handle cap
useBuySquare()           // Buy a grid cell
useAssignNumbers()       // Trigger randomization
useEnterScore()          // Admin enters quarterly score
useClaimSquaresPrize()   // Winner claims
useSquaresPool(poolId)   // Fetch and parse pool state
```

### 6. Constants

New file `web/src/constants/squares.ts`:
- Module name, function targets
- Default prize splits (e.g., `[2000, 2000, 2000, 4000]`)
- Grid size constant

---

## Implementation Order

### Phase 1: Move Contract
1. Create `sources/squares.move` with all structs and error codes
2. Implement `create()` and `buy_square()`
3. Implement `assign_numbers()` with `sui::random`
4. Implement `enter_score()` with winner resolution
5. Implement `claim_prize()` and `withdraw_remainder()`
6. Write tests in `tests/squares_tests.move`

### Phase 2: Frontend Foundation
7. Add catalog entry to `poolTypes.ts`
8. Add route to `App.tsx`
9. Create `SuperBowlSquaresPage.tsx` (landing page)
10. Create `CreateSquaresPoolPage.tsx`
11. Add transaction builders in `transactions/squares.ts`
12. Add blockchain constants in `constants/squares.ts`

### Phase 3: Grid UI & Interactions
13. Build the 10x10 grid component
14. Implement buy square interaction
15. Implement number assignment flow
16. Build score entry (admin view)
17. Build prize claim flow
18. Add winner highlighting and animations

---

## What This Design Does NOT Include (YAGNI)

- **Team names** — Not stored on-chain. Frontend can display them but they're cosmetic.
- **Multiple grids per pool** — One 10x10 grid per pool. Create a new pool for another grid.
- **Reverse/re-roll numbers** — Once assigned, numbers are permanent.
- **Partial grid play** — All 100 squares must be filled before numbers are assigned.
- **Time-based deadlines** — No clock gating. Admin controls the pace by when they enter scores.
- **Refunds** — No mechanism to refund if grid never fills. Could be added later.
- **Spectator view** — Pool page works for everyone, but only owners see claim buttons.
