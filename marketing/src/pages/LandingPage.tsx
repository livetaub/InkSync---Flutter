import { useEffect } from 'react';
import { Shield, Users, Zap, ArrowRight, Monitor, RefreshCw, CalendarDays, CheckSquare, PenTool } from 'lucide-react';
import './LandingPage.css';

const TESTIMONIALS = [
  { text: "I switched from Google Keep and never looked back. InkSync is clean, fast, and my notes are always in sync between my phone and laptop.", author: "Sarah Jenkins", role: "Product Manager", avatar: "S" },
  { text: "Finally a note-taking app that just works. No bloat, no clutter — just writing. And the real-time collab is perfect for my team.", author: "David Chen", role: "Software Engineer", avatar: "D" },
  { text: "My husband and I share grocery lists and trip plans through InkSync. It's become part of our daily routine.", author: "Emily Rodriguez", role: "Teacher", avatar: "E" },
  { text: "The offline support is a lifesaver. I write notes on my commute and everything syncs when I get to the office.", author: "Michael Chang", role: "Freelance Writer", avatar: "M" },
  { text: "I've tried Notion, Evernote, and Bear. InkSync is the perfect balance of simplicity and the features I actually use.", author: "Alex Mercer", role: "Student", avatar: "A" },
];

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

const FeatureCard = ({ icon, title, description, color }: { icon: React.ReactNode, title: string, description: string, color: string }) => (
  <div className="feature-card">
    <div className="feature-icon" style={{ backgroundColor: color }}>
      {icon}
    </div>
    <h3>{title}</h3>
    <p>{description}</p>
  </div>
);

const USE_CASES = [
  { emoji: "🎓", title: "Students", description: "Capture lecture notes, organize study guides, and create shared notes for group projects." },
  { emoji: "💼", title: "Professionals", description: "Draft meeting notes, share agendas, and collaborate with your team in real time." },
  { emoji: "✏️", title: "Creators", description: "Outline ideas, store reference material, and jot down inspiration on the go." },
  { emoji: "👨‍👩‍👧‍👦", title: "Families & Couples", description: "Share grocery lists, plan trips, and keep household notes perfectly in sync." },
];

const LandingPage = () => {
  const APP_URL = 'https://app.inksyncnote.com';
  const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.InkSync';

  useEffect(() => {
    const hash = window.location.hash;
    if (hash) {
      const element = document.querySelector(hash);
      if (element) {
        setTimeout(() => {
          element.scrollIntoView({ behavior: 'smooth' });
        }, 100);
      }
    }
  }, []);

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
            <span>Available on Android, iOS & Web</span>
          </div>
          
          <h1 className="hero-title">
            Simple notes, <br />
            <span className="text-gradient">perfectly in sync.</span>
          </h1>
          
          <p className="hero-subtitle">
            A clean, distraction-free note-taking app that syncs across all your devices. Write, organize, and share notes with the people who matter — no clutter, no complexity.
          </p>
          
          <div className="platform-icons">
            <a href={APP_URL} className="platform-icon" target="_blank" rel="noopener noreferrer">
              <Monitor size={24} />
              <span>Web</span>
            </a>
            <div className="platform-icon has-tooltip" onClick={() => alert('iOS app coming soon!')}>
              <AppleLogo size={24} />
              <span>Apple</span>
              <span className="platform-tooltip">Coming soon</span>
            </div>
            <a href={PLAY_STORE_URL} className="platform-icon" target="_blank" rel="noopener noreferrer">
              <AndroidLogo size={24} />
              <span>Android</span>
            </a>
          </div>
          
          <div className="hero-actions">
            <a href={`${APP_URL}/register`} className="btn-primary btn-large">
              Start Free — No Credit Card <ArrowRight size={18} />
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
          <h2>Everything you need, nothing you don't</h2>
          <p>Simple tools to write, organize, and share — across every device.</p>
        </div>

        <div className="grid grid-cols-3">
          <FeatureCard 
            icon={<RefreshCw size={28} color="#EAB308" />}
            title="Cross-Platform Sync"
            description="Write on your phone, pick up where you left off on any browser. Real-time cloud sync between Android, iOS, and the web."
            color="rgba(234, 179, 8, 0.12)"
          />
          <FeatureCard 
            icon={<Users size={28} color="#F97316" />}
            title="Real-Time Collaboration"
            description="Invite friends, family, or teammates to view and edit notes together. Perfect for shared lists, meeting notes, and group projects."
            color="rgba(249, 115, 22, 0.1)"
          />
          <FeatureCard 
            icon={<CheckSquare size={28} color="#22C55E" />}
            title="Checklists & Organization"
            description="Create to-do lists inside any note. Organize with custom tags, color-coded notebooks, and instant search."
            color="rgba(34, 197, 94, 0.1)"
          />
          <FeatureCard 
            icon={<CalendarDays size={28} color="#3B82F6" />}
            title="Calendar Integration"
            description="Link notes to dates and events. Browse chronologically to recall what you wrote and when."
            color="rgba(59, 130, 246, 0.1)"
          />
          <FeatureCard 
            icon={<Shield size={28} color="#57534E" />}
            title="Privacy & Note Locking"
            description="Password-protect sensitive notes or entire notebooks. Your private thoughts stay private."
            color="rgba(87, 83, 78, 0.1)"
          />
          <FeatureCard 
            icon={<PenTool size={28} color="#A855F7" />}
            title="AI Writing Assist"
            description="Summarize long notes, extract action items, or brainstorm ideas — a helpful assistant when you need it."
            color="rgba(168, 85, 247, 0.1)"
          />
        </div>
      </section>

      {/* Who Uses InkSync Section */}
      <section className="use-cases-section">
        <div className="container">
          <div className="section-header">
            <h2>Built for the way you work</h2>
            <p>Whether you're studying, working, or running a household — InkSync fits right in.</p>
          </div>
          <div className="grid grid-cols-4">
            {USE_CASES.map((item, i) => (
              <div key={i} className="use-case-card">
                <span className="use-case-emoji">{item.emoji}</span>
                <h3>{item.title}</h3>
                <p>{item.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section id="testimonials" className="testimonials-section">
        <div className="testimonials-header">
          <h2>Loved by real people</h2>
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
            <h2>Ready to simplify your notes?</h2>
            <p>Join thousands who write, organize, and share — without the clutter.</p>
            <a href={`${APP_URL}/register`} className="btn-primary btn-large cta-btn">
              Create Your Free Account
            </a>
          </div>
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="download-section container">
        <div className="download-content glass-panel">
          <h2>Get InkSync on your device</h2>
          <p>Available on Android and the web. Your notes stay perfectly in sync across every device you use.</p>
          <div className="store-buttons">
            <a href="#" className="store-btn" onClick={(e) => e.preventDefault()} title="Coming Soon">
              <AppleLogo size={28} />
              <div className="store-text">
                <span>Download on the</span>
                <strong>App Store</strong>
              </div>
            </a>
            <a href={PLAY_STORE_URL} className="store-btn" target="_blank" rel="noopener noreferrer">
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
              <img src="/logo.png" alt="InkSync Logo" style={{ width: 18, height: 18, objectFit: 'contain' }} />
            </div>
            <span className="brand-text">InkSync</span>
          </div>
          <div className="footer-links">
            <a href={`${APP_URL}/login`}>Sign In</a>
            <a href="mailto:support@inksyncnote.com">Contact</a>
            <a href="/terms">Privacy & Terms</a>
          </div>
        </div>
        <div className="footer-bottom">
          © {new Date().getFullYear()} InkSync. All rights reserved.
        </div>
      </footer>
    </div>
  );
};

export default LandingPage;
