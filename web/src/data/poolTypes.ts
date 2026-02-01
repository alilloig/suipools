export interface PoolType {
  id: string;
  title: string;
  icon: string;
  tagline: string;
  route: string;
  enabled: boolean;
}

export const POOL_TYPES: PoolType[] = [
  {
    id: "world-cup",
    title: "World Cup 2026",
    icon: "⚽",
    tagline: "Predict every match from groups to the final",
    route: "/world-cup",
    enabled: true,
  },
  {
    id: "super-bowl-squares",
    title: "Super Bowl Squares",
    icon: "🏈",
    tagline: "Pick your squares, pray for the right digits",
    route: "/super-bowl-squares",
    enabled: true,
  },
];
