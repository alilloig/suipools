import { HashRouter, Routes, Route } from "react-router-dom";
import { Header } from "./components/layout/Header";
import { Footer } from "./components/layout/Footer";
import { PageContainer } from "./components/layout/PageContainer";
import { HomePage } from "./pages/HomePage";
import { CreatePoolPage } from "./pages/CreatePoolPage";
import { PoolPage } from "./pages/PoolPage";
import { AdminPage } from "./pages/AdminPage";
import { NotFoundPage } from "./pages/NotFoundPage";
import { WorldCupPage } from "./pages/WorldCupPage";

function App() {
  return (
    <HashRouter>
      <div className="min-h-screen flex flex-col bg-pitch-dark text-gray-100">
        <Header />
        <PageContainer>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/world-cup" element={<WorldCupPage />} />
            <Route path="/create" element={<CreatePoolPage />} />
            <Route path="/pool/:poolId" element={<PoolPage />} />
            <Route path="/admin" element={<AdminPage />} />
            <Route path="*" element={<NotFoundPage />} />
          </Routes>
        </PageContainer>
        <Footer />
      </div>
    </HashRouter>
  );
}

export default App;
