import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Menu, X, RefreshCw } from 'lucide-react';
import './Navbar.css';

const Navbar = () => {
  const [isOpen, setIsOpen] = useState(false);
  const APP_URL = 'https://app.inksyncnote.com';

  return (
    <nav className="navbar glass-panel">
      <div className="container nav-container">
        <Link to="/" className="brand">
          <div className="logo-icon">
            <img src="/logo.png" alt="InkSync Logo" style={{ width: 24, height: 24, objectFit: 'contain' }} />
          </div>
          <span className="brand-text">InkSync</span>
        </Link>

        {/* Desktop Nav */}
        <div className="desktop-nav">
          <Link to="/" className="nav-link">Home</Link>
          <a href="/#features" className="nav-link">Features</a>
          <Link to="/pricing" className="nav-link">Pricing</Link>
          <div className="nav-divider"></div>
          <a href={`${APP_URL}/login`} className="nav-link">Sign In</a>
          <a href={`${APP_URL}/register`} className="btn-primary" style={{ padding: '10px 20px' }}>
            Get Started Free
          </a>
        </div>

        {/* Mobile Nav Toggle */}
        <button className="mobile-toggle" onClick={() => setIsOpen(!isOpen)}>
          {isOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
      </div>

      {/* Mobile Nav Menu */}
      {isOpen && (
        <div className="mobile-menu glass-panel animate-fade-up">
          <Link to="/" className="mobile-link" onClick={() => setIsOpen(false)}>Home</Link>
          <a href="/#features" className="mobile-link" onClick={() => setIsOpen(false)}>Features</a>
          <Link to="/pricing" className="mobile-link" onClick={() => setIsOpen(false)}>Pricing</Link>
          <div className="mobile-divider"></div>
          <a href={`${APP_URL}/login`} className="mobile-link" onClick={() => setIsOpen(false)}>Sign In</a>
          <a href={`${APP_URL}/register`} className="btn-primary mobile-btn" onClick={() => setIsOpen(false)}>
            Get Started Free
          </a>
        </div>
      )}
    </nav>
  );
};

export default Navbar;
