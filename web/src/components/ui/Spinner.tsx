export function Spinner({ className = "w-8 h-8", message }: { className?: string; message?: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3">
      <svg className={`animate-spin text-pitch-light ${className}`} fill="none" viewBox="0 0 24 24">
        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
      </svg>
      {message && <p className="text-gray-400 text-sm">{message}</p>}
    </div>
  );
}
