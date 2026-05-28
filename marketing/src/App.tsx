import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import LandingPage from './pages/LandingPage';
import PricingPage from './pages/PricingPage';
import TermsPage from './pages/TermsPage';
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
        <Route path="/pricing" element={<PricingPage />} />
        <Route path="/terms" element={<TermsPage />} />
      </Routes>
    </Router>
  );
}

export default App;
