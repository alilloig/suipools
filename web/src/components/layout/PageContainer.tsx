import { ReactNode } from "react";

export function PageContainer({ children }: { children: ReactNode }) {
  return (
    <main className="flex-1 max-w-6xl mx-auto w-full px-4 py-8">
      {children}
    </main>
  );
}
