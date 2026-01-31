/// Module: scoring
/// Pure scoring helpers for the World Cup SuiPoolool.
/// Maps match indices to phases, groups, deadlines, and computes points.
///
/// Match index layout (104 total):
///   Groups:  0-71  (12 groups × 6 matches; group g = matches g*6..g*6+5)
///   R32:     72-87
///   R16:     88-95
///   QF:      96-99
///   SF:      100-101
///   3rd:     102
///   Final:   103
module world_cup_pool::scoring;

// === Constants ===

/// Total number of matches in the tournament
const TOTAL_MATCHES: u64 = 104;

/// Number of groups
const NUM_GROUPS: u64 = 12;

/// Matches per group
const MATCHES_PER_GROUP: u64 = 6;

/// Points per phase
const POINTS_GROUP: u64 = 1;
const POINTS_R32: u64 = 2;
const POINTS_R16: u64 = 3;
const POINTS_QF: u64 = 5;
const POINTS_SF: u64 = 8;
const POINTS_3RD: u64 = 8;
const POINTS_FINAL: u64 = 13;

/// Group bonus points for getting all 6 matches in a group correct
const GROUP_BONUS: u64 = 3;

/// Phase indices (for deadline mapping)
const PHASE_GROUP: u8 = 0;
const PHASE_R32: u8 = 1;
const PHASE_R16: u8 = 2;
const PHASE_QF: u8 = 3;
const PHASE_SF: u8 = 4;
const PHASE_3RD: u8 = 5;
const PHASE_FINAL: u8 = 6;

// === Public Functions ===

/// Returns the total number of matches in the tournament.
public fun total_matches(): u64 {
    TOTAL_MATCHES
}

/// Returns the number of groups.
public fun num_groups(): u64 {
    NUM_GROUPS
}

/// Returns the number of matches per group.
public fun matches_per_group(): u64 {
    MATCHES_PER_GROUP
}

/// Returns the group bonus point value.
public fun group_bonus_points(): u64 {
    GROUP_BONUS
}

/// Returns the phase (0-6) for a given match index.
public fun phase_for_match(match_idx: u64): u8 {
    if (match_idx < 72) {
        PHASE_GROUP
    } else if (match_idx < 88) {
        PHASE_R32
    } else if (match_idx < 96) {
        PHASE_R16
    } else if (match_idx < 100) {
        PHASE_QF
    } else if (match_idx < 102) {
        PHASE_SF
    } else if (match_idx == 102) {
        PHASE_3RD
    } else {
        PHASE_FINAL
    }
}

/// Returns the deadline index (0-6) for a given match index.
/// This is the same as phase_for_match since each phase has one deadline.
public fun deadline_index_for_match(match_idx: u64): u64 {
    (phase_for_match(match_idx) as u64)
}

/// Returns the group index (0-11) for a group-stage match.
/// Aborts if the match is not in the group stage.
public fun group_index_for_match(match_idx: u64): u64 {
    assert!(match_idx < 72);
    match_idx / MATCHES_PER_GROUP
}

/// Returns the point value for correctly predicting a match at the given index.
public fun points_for_match(match_idx: u64): u64 {
    let phase = phase_for_match(match_idx);
    if (phase == PHASE_GROUP) {
        POINTS_GROUP
    } else if (phase == PHASE_R32) {
        POINTS_R32
    } else if (phase == PHASE_R16) {
        POINTS_R16
    } else if (phase == PHASE_QF) {
        POINTS_QF
    } else if (phase == PHASE_SF) {
        POINTS_SF
    } else if (phase == PHASE_3RD) {
        POINTS_3RD
    } else {
        POINTS_FINAL
    }
}

/// Checks whether all 6 matches in a given group have results entered.
/// `results` is the 104-element results vector.
public fun is_group_complete(results: &vector<u8>, group_idx: u64): bool {
    let start = group_idx * MATCHES_PER_GROUP;
    let mut i = 0;
    while (i < MATCHES_PER_GROUP) {
        if (*results.borrow(start + i) == 0) {
            return false
        };
        i = i + 1;
    };
    true
}

/// Checks if a participant got all 6 matches correct in a group.
/// Returns the bonus points (GROUP_BONUS) if all correct, 0 otherwise.
/// `bets` and `results` are 104-element vectors.
public fun check_group_bonus(bets: &vector<u8>, results: &vector<u8>, group_idx: u64): u64 {
    let start = group_idx * MATCHES_PER_GROUP;
    let mut i = 0;
    while (i < MATCHES_PER_GROUP) {
        let idx = start + i;
        if (*bets.borrow(idx) != *results.borrow(idx)) {
            return 0
        };
        i = i + 1;
    };
    GROUP_BONUS
}

/// Compute total score for a participant in one pass.
/// Iterates all 104 matches for point-based scoring, then checks all 12 group bonuses.
public fun compute_total_score(bets: &vector<u8>, results: &vector<u8>): u64 {
    let mut score: u64 = 0;

    // Score all 104 matches
    let mut i: u64 = 0;
    while (i < TOTAL_MATCHES) {
        let bet = *bets.borrow(i);
        let result = *results.borrow(i);
        if (bet != 0 && result != 0 && bet == result) {
            score = score + points_for_match(i);
        };
        i = i + 1;
    };

    // Check all 12 group bonuses
    let mut g: u64 = 0;
    while (g < NUM_GROUPS) {
        score = score + check_group_bonus(bets, results, g);
        g = g + 1;
    };

    score
}
