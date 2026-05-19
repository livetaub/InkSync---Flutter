import { Shield, Sparkles, Users, Zap, ArrowRight, RefreshCw, Monitor } from 'lucide-react';
import './LandingPage.css';

const TESTIMONIALS = [
  { text: "InkSync completely transformed my workflow. Having my notes instantly available everywhere is a game changer.", author: "Sarah Jenkins", role: "Product Manager", avatar: "S" },
  { text: "The cleanest, fastest note-taking app I've ever used. It feels like a premium productivity tool.", author: "David Chen", role: "Software Engineer", avatar: "D" },
  { text: "Finally, a cross-platform notes app that gets the details right. The UI is absolutely gorgeous.", author: "Emily Rodriguez", role: "Designer", avatar: "E" },
  { text: "I love the offline-first approach. It's incredibly fast and syncing just works in the background.", author: "Michael Chang", role: "Freelance Writer", avatar: "M" },
  { text: "I've tried everything else. InkSync is the perfect balance of simplicity and power.", author: "Alex Mercer", role: "Student", avatar: "A" },
];

const LandingPage = () => {
  const APP_URL = 'https://app.inksyncnote.com';

  return (
    <div className="landing-page">
      {/* Background Elements */}
      <div className="bg-orbs">
        <div className="orb orb-1 animate-float"></div>
        <div className="orb orb-2 animate-float" style={{ animationDelay: '2s' }}></div>
        <div className="orb orb-3 animate-float" style={{ animationDelay: '4s' }}></div>
      </div>

      {/* Hero Section */}
      <section className="hero container">
        <div className="hero-content animate-fade-up">
          <div className="badge">
            <Zap size={16} color="var(--primary)" />
            <span>Now available on iOS, Android & Web</span>
          </div>
          
          <h1 className="hero-title">
            Your thoughts, <br />
            <span className="text-gradient">perfectly in sync.</span>
          </h1>
          
          <p className="hero-subtitle">
            Stop losing notes between devices. InkSync keeps your notes, checklists, and ideas beautifully organized and instantly synced across every platform.
          </p>
          
          <div className="platform-icons">
            <div className="platform-icon">
              <Monitor size={24} />
              <span>Web</span>
            </div>
            <div className="platform-icon">
              <AppleLogo size={24} />
              <span>Apple</span>
            </div>
            <div className="platform-icon">
              <AndroidLogo size={24} />
              <span>Android</span>
            </div>
          </div>
          
          <div className="hero-actions">
            <a href={`${APP_URL}/register`} className="btn-primary btn-large">
              Start Free — No Credit Card <ArrowRight size={18} />
            </a>
            <a href="/pricing" className="btn-outline btn-large">
              View Pricing
            </a>
          </div>
          <p className="hero-disclaimer">Free forever • No credit card required</p>
        </div>

        <div className="hero-image-wrapper animate-fade-up delay-200">
          <img src="/images/hero_image.png" alt="InkSync App Preview" className="hero-image" />
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="features-section container">
        <div className="section-header">
          <h2>Everything you need</h2>
          <p>Powerful features, beautifully simple.</p>
        </div>

        <div className="grid grid-cols-3">
          <FeatureCard 
            icon={<Sparkles size={28} color="#EAB308" />}
            title="Cross-Platform Sync"
            description="Your notes follow you everywhere — phone, tablet, laptop. Always up to date."
            color="rgba(234, 179, 8, 0.12)"
          />
          <FeatureCard 
            icon={<Users size={28} color="#F97316" />}
            title="Real-Time Collab"
            description="Invite others to edit notes together. See changes live, no refresh needed."
            color="rgba(249, 115, 22, 0.1)"
          />
          <FeatureCard 
            icon={<Shield size={28} color="#57534E" />}
            title="Note Locking"
            description="Password-protect sensitive notes. Your private thoughts stay private."
            color="rgba(87, 83, 78, 0.1)"
          />
        </div>
      </section>

      {/* Testimonials Section */}
      <section className="testimonials-section">
        <div className="testimonials-header">
          <h2>Loved by professionals</h2>
        </div>
        
        {/* We render the list twice to create a seamless infinite loop effect */}
        <div className="marquee-container">
          {[...TESTIMONIALS, ...TESTIMONIALS].map((testimonial, i) => (
            <div key={i} className="testimonial-card">
              <p className="testimonial-text">"{testimonial.text}"</p>
              <div className="testimonial-author">
                <div className="author-avatar">{testimonial.avatar}</div>
                <div className="author-info">
                  <h4>{testimonial.author}</h4>
                  <p>{testimonial.role}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* CTA Section */}
      <section className="cta-section">
        <div className="container">
          <div className="cta-box glass-panel">
            <h2>Ready to sync your thoughts?</h2>
            <p>Join thousands who never lose a note again.</p>
            <a href={`${APP_URL}/register`} className="btn-primary btn-large cta-btn">
              Create Your Free Account
            </a>
          </div>
        </div>
      </section>

      {/* Download Section */}
      <section className="download-section container">
        <div className="download-content glass-panel">
          <h2>Get InkSync on your device</h2>
          <p>Download the app for iOS and Android to keep your thoughts synced everywhere you go.</p>
          <div className="store-buttons">
            <a href="#" className="store-btn">
              <AppleLogo size={28} />
              <div className="store-text">
                <span>Download on the</span>
                <strong>App Store</strong>
              </div>
            </a>
            <a href="#" className="store-btn">
              <GooglePlayLogo size={28} />
              <div className="store-text">
                <span>GET IT ON</span>
                <strong>Google Play</strong>
              </div>
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer container">
        <div className="footer-content">
          <div className="brand">
            <div className="logo-icon" style={{ width: 32, height: 32 }}>
              <RefreshCw size={18} color="#fff" />
            </div>
            <span className="brand-text">InkSync</span>
          </div>
          <div className="footer-links">
            <a href="/pricing">Pricing</a>
            <a href={`${APP_URL}/login`}>Sign In</a>
          </div>
        </div>
        <div className="footer-bottom">
          © {new Date().getFullYear()} InkSync. All rights reserved.
        </div>
      </footer>
    </div>
  );
};

const FeatureCard = ({ icon, title, description, color }: { icon: React.ReactNode, title: string, description: string, color: string }) => (
  <div className="feature-card">
    <div className="feature-icon" style={{ backgroundColor: color }}>
      {icon}
    </div>
    <h3>{title}</h3>
    <p>{description}</p>
  </div>
);

export default LandingPage;

// Brand SVG Components
const AppleLogo = ({ size = 24 }: { size?: number }) => (
  <svg viewBox="0 0 384 512" width={size} height={size} fill="currentColor">
    <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/>
  </svg>
);

const AndroidLogo = ({ size = 24 }: { size?: number }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill="currentColor">
    <path d="M18.4395 5.5586c-.675 1.1664-1.352 2.3318-2.0274 3.498-.0366-.0155-.0742-.0286-.1113-.043-1.8249-.6957-3.484-.8-4.42-.787-1.8551.0185-3.3544.4643-4.2597.8203-.084-.1494-1.7526-3.021-2.0215-3.4864a1.1451 1.1451 0 0 0-.1406-.1914c-.3312-.364-.9054-.4859-1.379-.203-.475.282-.7136.9361-.3886 1.5019 1.9466 3.3696-.0966-.2158 1.9473 3.3593.0172.031-.4946.2642-1.3926 1.0177C2.8987 12.176.452 14.772 0 18.9902h24c-.119-1.1108-.3686-2.099-.7461-3.0683-.7438-1.9118-1.8435-3.2928-2.7402-4.1836a12.1048 12.1048 0 0 0-2.1309-1.6875c.6594-1.122 1.312-2.2559 1.9649-3.3848.2077-.3615.1886-.7956-.0079-1.1191a1.1001 1.1001 0 0 0-.8515-.5332c-.5225-.0536-.9392.3128-1.0488.5449zm-.0391 8.461c.3944.5926.324 1.3306-.1563 1.6503-.4799.3197-1.188.0985-1.582-.4941-.3944-.5927-.324-1.3307.1563-1.6504.4727-.315 1.1812-.1086 1.582.4941zM7.207 13.5273c.4803.3197.5506 1.0577.1563 1.6504-.394.5926-1.1038.8138-1.584.4941-.48-.3197-.5503-1.0577-.1563-1.6504.4008-.6021 1.1087-.8106 1.584-.4941z"/>
  </svg>
);

const GooglePlayLogo = ({ size = 24 }: { size?: number }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} fill="currentColor">
    <path d="M22.018 13.298l-3.919 2.218-3.515-3.493 3.543-3.521 3.891 2.202a1.49 1.49 0 0 1 0 2.594zM1.337.924a1.486 1.486 0 0 0-.112.568v21.017c0 .217.045.419.124.6l11.155-11.087L1.337.924zm12.207 10.065l3.258-3.238L3.45.195a1.466 1.466 0 0 0-.946-.179l11.04 10.973zm0 2.067l-11 10.933c.298.036.612-.016.906-.183l13.324-7.54-3.23-3.21z"/>
  </svg>
);
