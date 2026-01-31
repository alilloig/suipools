interface TabsProps {
  tabs: { key: string; label: string }[];
  activeTab: string;
  onTabChange: (key: string) => void;
}

export function Tabs({ tabs, activeTab, onTabChange }: TabsProps) {
  return (
    <div className="flex gap-1 overflow-x-auto border-b border-gray-700 pb-px">
      {tabs.map((tab) => (
        <button
          key={tab.key}
          onClick={() => onTabChange(tab.key)}
          className={`px-3 py-2 text-sm font-medium whitespace-nowrap rounded-t-lg transition-colors ${
            activeTab === tab.key
              ? "bg-gray-700 text-white border-b-2 border-pitch-light"
              : "text-gray-400 hover:text-gray-200 hover:bg-gray-800"
          }`}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
