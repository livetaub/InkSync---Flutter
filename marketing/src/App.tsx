import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import LandingPage from './pages/LandingPage';
import NotFoundPage from './pages/NotFoundPage';
import TermsPage from './pages/TermsPage';
import ComparisonPage from './pages/ComparisonPage';
import AlternativePage from './pages/AlternativePage';
import WedgePage from './pages/WedgePage';
import './App.css';

function App() {
  // Subdomain routing detection for terms.inksyncnote.com
  const isTermsSubdomain = window.location.hostname === 'terms.inksyncnote.com';

  if (isTermsSubdomain) {
    return (
      <Router>
        <Routes>
          <Route path="/*" element={<TermsPage />} />
        </Routes>
      </Router>
    );
  }

  return (
    <Router>
      <Navbar />
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/terms" element={<TermsPage />} />
        <Route path="/compare/:slug" element={<ComparisonPage />} />
        <Route path="/alternative/:slug" element={<AlternativePage />} />
        <Route path="/shared-grocery-list-app" element={<WedgePage slug="shared-grocery-list-app" />} />
        <Route path="/notes-app-for-couples" element={<WedgePage slug="notes-app-for-couples" />} />
        <Route path="/family-shared-notes-app" element={<WedgePage slug="family-shared-notes-app" />} />
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </Router>
  );
}

export default App;

