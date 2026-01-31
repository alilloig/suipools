import { Link } from "react-router-dom";
import { Button } from "../components/ui/Button";

export function NotFoundPage() {
  return (
    <div className="flex flex-col items-center justify-center py-20 text-center">
      <h1 className="text-6xl font-bold text-gray-600">404</h1>
      <p className="text-gray-400 text-lg mt-4">Page not found</p>
      <Link to="/" className="mt-6">
        <Button variant="secondary">Back to Home</Button>
      </Link>
    </div>
  );
}
