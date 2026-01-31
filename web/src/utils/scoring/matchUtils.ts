import { SCHEDULE } from "../../data/schedule";
import { Match, Phase } from "../../types/match";
import { PHASES } from "../../data/phases";
import { groupIndexForMatch } from "./points";
import { GROUP_IDS } from "../../data/groups";

export function getMatchesByPhase(phase: Phase): Match[] {
  const phaseInfo = PHASES.find((p) => p.phase === phase);
  if (!phaseInfo) return [];
  return SCHEDULE.filter(
    (m) => m.matchIndex >= phaseInfo.matchStart && m.matchIndex < phaseInfo.matchEnd,
  );
}

export function getMatchesByGroup(groupId: string): Match[] {
  return SCHEDULE.filter((m) => m.group === groupId);
}

export function getGroupIdForMatch(matchIndex: number): string | null {
  if (matchIndex >= 72) return null;
  const groupIdx = groupIndexForMatch(matchIndex);
  return GROUP_IDS[groupIdx];
}

export function getPhaseLabel(phase: Phase): string {
  const info = PHASES.find((p) => p.phase === phase);
  return info?.label ?? "Unknown";
}
