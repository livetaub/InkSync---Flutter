import { useEffect, useState } from 'react';
import { Shield, Users, Zap, ArrowRight, Monitor, RefreshCw, CalendarDays, CheckSquare, PenTool, ChevronDown, Star, Smartphone, FileText, Share2, WifiOff, Brain } from 'lucide-react';
import { useDocumentMetadata } from '../hooks/useDocumentMetadata';
import './LandingPage.css';

const TESTIMONIALS = [
  { text: "I was using Apple Notes and Google Keep across different devices and it was a mess. InkSync fixed that — one app, everything in sync. I use it for class notes, grocery lists, everything.", author: "Priya M.", avatar: "P", stars: 5 },
  { text: "Our team switched from a shared Google Doc to InkSync for meeting notes. The real-time collab is smooth and way less cluttered. Plus my personal notes stay separate.", author: "James W.", avatar: "J", stars: 5 },
  { text: "I write on my phone during my commute and pick up right where I left off on my laptop. The sync is genuinely instant. No fiddling with exports or cloud drives.", author: "Maria S.", avatar: "M", stars: 5 },
  { text: "My wife and I share grocery lists, packing lists, and home project notes through InkSync. It replaced our fridge whiteboard. Simple, fast, and always up to date.", author: "Tom H.", avatar: "T", stars: 4 },
  { text: "I have tried Notion, Bear, and Simplenote. InkSync hits the sweet spot — it has checklists, brain dump, and AI features without the bloat. It is the only notes app I have stuck with.", author: "Riki T.", avatar: "R", stars: 5 },
];

const FAQ_ITEMS = [
  { question: "What is InkSync?", answer: "InkSync is a cross-platform note-taking app designed for simplicity, offline reliability, and seamless sync. It works on Android, iOS, and the web, with local-first storage so your notes are always available even without an internet connection." },
  { question: "Is InkSync free to use?", answer: "Yes. InkSync offers a generous free plan that includes up to 150 notes & checklists, and real-time cross-platform sync across your Android, iOS, and Web devices. If you need more capacity, multi-user collaboration, or other Premium features, InkSync Premium is available starting at .99¢ per week ($33.99/year)." },
  { question: "Which devices does InkSync work on?", answer: "InkSync is available on Android via Google Play, on any modern web browser at app.inksyncnote.com, and an iOS app is coming soon. Your mobile app works 100% offline and syncs across all your devices in real time whenever connected." },
  { question: "Can I share and collaborate notes with other people?", answer: "Absolutely. InkSync Premium supports multi-user note sharing & collaboration — you can invite anyone by email to view or edit a note together. It works great for shared grocery lists, meeting notes, group projects, and travel planning." },
  { question: "Is my data private and secure?", answer: "Yes. InkSync takes privacy seriously. You can password-protect your notes. Your data is stored securely on encrypted cloud infrastructure." },
  { question: "Does InkSync sell my data?", answer: "No. InkSync never sells your personal data or note content to advertisers or third parties." },
  { question: "What is the Brain Dump feature?", answer: "Brain Dump is a dedicated section designed for fast, frictionless thought capture. Similar to messaging yourself, you can quickly type notes, attach images, and record voice notes on the fly without worrying about folder setup or titles." },
  { question: "Will I lose my notes if I have a poor internet connection?", answer: "No, never. InkSync is built local-first for mobile. Every note you write is saved directly to your device local storage first, so even if your connection drops, freezes, or disappears completely, your work is 100% safe and available offline. Once you reconnect, InkSync automatically syncs your changes." },
  { question: "How is InkSync different from Google Keep or Apple Notes?", answer: "Unlike Google Keep or Apple Notes, InkSync is truly cross-platform and local-first — it works offline on mobile and syncs across Android, iOS, and the web for free. InkSync Premium also offers multi-user note sharing & collaboration, a dedicated Brain Dump section with voice notes and images, AI writing tools to proofread and rewrite with custom tones, and password locking for sensitive notes." },
  { question: "What happens to my notes if I cancel Premium?", answer: "Your notes are always yours. If you downgrade from InkSync Premium to the free plan, all your existing notes remain stored locally and cloud-accessible. You can export your data at any time." },
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
  { emoji: "✏️", title: "Creators", description: "Brain dump raw ideas, voice notes, images, and outline drafts on the go." },
  { emoji: "👨‍👩‍👧‍👦", title: "Families & Couples", description: "Share grocery lists, plan trips, and keep household notes perfectly in sync." },
];

const LandingPage = () => {
  const APP_URL = 'https://app.inksyncnote.com';
  const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.InkSync';
  const [openFaq, setOpenFaq] = useState<number | null>(null);

  useDocumentMetadata(
    "InkSync — Simple, Clean & Cross-Platform Note-Taking",
    "A clean, distraction-free note-taking app that syncs seamlessly across Android, iOS, and the web. Write, organize, and collaborate without the clutter."
  );

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

      <main id="main-content">
        {/* Hero Section */}
        <section className="hero container">
          <div className="hero-content animate-fade-up">
            <div className="badge">
              <Zap size={16} color="var(--primary)" />
              <span>Available on Android, iOS & Web • Local-First</span>
            </div>
            
            <h1 className="hero-title">
              The note-taking app that<br />
              <span className="text-gradient">syncs everywhere.</span>
            </h1>
            
            <p className="hero-subtitle">
              InkSync is a local-first note-taking app that works 100% offline and syncs seamlessly across Android, iOS, and the web. Write, organize, and share notes without clutter or connectivity worries.
            </p>
            
            <div className="platform-icons">
              <a href={APP_URL} className="platform-icon" target="_blank" rel="noopener noreferrer">
                <Monitor size={24} />
                <span>Web</span>
              </a>
              <div className="platform-icon has-tooltip">
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
              <a href="#features" className="btn-outline btn-large">
                Explore Features
              </a>
            </div>
            <p className="hero-disclaimer">Free forever • Cancel anytime</p>
          </div>

          <div className="hero-image-wrapper animate-fade-up delay-200">
            <img src="/images/hero_image.jpg" alt="InkSync app showing notes list and editor with cross-platform sync across phone and browser" className="hero-image" fetchPriority="high" />
          </div>
        </section>

        {/* Social Proof Bar */}
        <section className="social-proof-bar">
          <div className="container proof-items">
            <div className="proof-item">
              <Smartphone size={24} />
              <span><strong>3</strong> Platforms</span>
            </div>
            <div className="proof-item">
              <FileText size={24} />
              <span><strong>25,000+</strong> Notes Created</span>
            </div>
            <div className="proof-item">
              <WifiOff size={24} />
              <span><strong>100%</strong> Offline Ready</span>
            </div>
            <div className="proof-item">
              <Zap size={24} />
              <span><strong>Real-Time</strong> Sync</span>
            </div>
          </div>
        </section>

        {/* Problem Section */}
        <section className="problem-section">
          <div className="container">
            <div className="section-header">
              <h2>Sound familiar?</h2>
              <p>Most note-taking apps create more problems than they solve.</p>
            </div>
            <div className="grid grid-cols-2 problem-grid">
              <div className="problem-card">
                <span className="problem-emoji">📡❌</span>
                <h3>Fails without internet</h3>
                <p>You need to write down a quick note, but the app freezes or blocks you because you lost reception or don't have Wi-Fi.</p>
              </div>
              <div className="problem-card">
                <span className="problem-emoji">🔍</span>
                <h3>Scattered across too many apps</h3>
                <p>Google Keep for lists. Apple Notes for long-form. A shared doc for work. Nothing in one place, nothing in sync.</p>
              </div>
              <div className="problem-card">
                <span className="problem-emoji">🤯</span>
                <h3>Too complex to just write</h3>
                <p>You wanted a note, not a database. Some apps turn simple writing into a project management exercise.</p>
              </div>
              <div className="problem-card">
                <span className="problem-emoji">🔓</span>
                <h3>No privacy when you need it</h3>
                <p>Personal thoughts, passwords, private lists — most apps don't let you lock individual notes from prying eyes.</p>
              </div>
            </div>
          </div>
        </section>

        {/* Features Section */}
        <section id="features" className="features-section container">
          <div className="section-header">
            <h2>Everything you need to write, nothing you don't</h2>
            <p>InkSync gives you everything you need to write, organize, and share — across every device.</p>
          </div>

          <div className="grid grid-cols-4">
            <FeatureCard 
              icon={<WifiOff size={26} color="#05D07D" />}
              title="Local-first & works offline"
              description="The mobile app stores notes directly on your device. Write and read seamlessly without an internet connection — never fail when offline."
              color="rgba(5, 208, 125, 0.12)"
            />
            <FeatureCard 
              icon={<Brain size={26} color="#EC4899" />}
              title="Dedicated Brain Dump"
              description="A dedicated space to quickly capture raw thoughts, attach images, and record voice notes — just like messaging yourself on the fly."
              color="rgba(236, 72, 153, 0.12)"
            />
            <FeatureCard 
              icon={<RefreshCw size={26} color="#EAB308" />}
              title="Your notes, on every device"
              description="Write on your phone, pick up where you left off on any browser. InkSync keeps everything in sync across Android, iOS, and the web."
              color="rgba(234, 179, 8, 0.12)"
            />
            <FeatureCard 
              icon={<Users size={26} color="#F97316" />}
              title="Collaborate in real time"
              description="Invite friends, family, or teammates to view and edit notes together. Perfect for shared lists, meeting notes, and group projects."
              color="rgba(249, 115, 22, 0.1)"
            />
            <FeatureCard 
              icon={<CheckSquare size={26} color="#22C55E" />}
              title="Stay organized with checklists"
              description="Create to-do lists. Organize with custom tags, color-coded notebooks, and instant search."
              color="rgba(34, 197, 94, 0.1)"
            />
            <FeatureCard 
              icon={<PenTool size={26} color="#A855F7" />}
              title="Write smarter with AI"
              description="Proofread and rewrite notes with your selected tone — InkSync's AI assistant helps polish your writing whenever you need it."
              color="rgba(168, 85, 247, 0.1)"
            />
            <FeatureCard 
              icon={<Shield size={26} color="#57534E" />}
              title="Keep private notes private"
              description="Password-protect sensitive notes. Your private thoughts stay private."
              color="rgba(87, 83, 78, 0.1)"
            />
            <FeatureCard 
              icon={<CalendarDays size={26} color="#3B82F6" />}
              title="Link notes to your calendar"
              description="Attach notes to dates and events. Browse chronologically to recall what you wrote and when."
              color="rgba(59, 130, 246, 0.1)"
            />
          </div>
        </section>

        {/* How It Works Section */}
        <section className="how-it-works-section">
          <div className="container">
            <div className="section-header">
              <h2>Start writing in under 60 seconds</h2>
              <p>Get started in under a minute. No complicated setup required.</p>
            </div>
            <div className="steps-container">
              <div className="step">
                <div className="step-number">1</div>
                <div className="step-icon">
                  <PenTool size={28} />
                </div>
                <h3>Create or Brain Dump</h3>
                <p>Open InkSync on any device. Instantly capture raw ideas, voice notes, and images in Brain Dump or create structured notes and checklists.</p>
              </div>
              <div className="step">
                <div className="step-number">2</div>
                <div className="step-icon">
                  <RefreshCw size={28} />
                </div>
                <h3>Sync automatically</h3>
                <p>Your notes are stored locally first and sync instantly across Android, iOS, and the web when connected.</p>
              </div>
              <div className="step">
                <div className="step-number">3</div>
                <div className="step-icon">
                  <Share2 size={28} />
                </div>
                <h3>Share and collaborate</h3>
                <p>Invite anyone by email to view or edit your notes together in real time.</p>
              </div>
            </div>
          </div>
        </section>

        {/* Who Uses InkSync Section */}
        <section className="use-cases-section">
          <div className="container">
            <div className="section-header">
              <h2>Who uses InkSync</h2>
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
            <a href={`${APP_URL}/register`} className="section-cta">
              Start writing for free &rarr;
            </a>
          </div>
        </section>

        {/* Comparison Section */}
        <section className="comparison-section container">
          <div className="section-header">
            <h2>How InkSync compares</h2>
            <p>See how InkSync stacks up against other popular note-taking apps.</p>
          </div>
          <div className="comparison-table-wrapper">
            <table className="comparison-table">
              <thead>
                <tr>
                  <th>Feature</th>
                  <th className="highlight-col">InkSync</th>
                  <th>Google Keep</th>
                  <th>Apple Notes</th>
                  <th>Notion</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Local-first (works 100% offline)</td>
                  <td className="highlight-col"><span className="check">✓</span></td>
                  <td><span className="partial">Partial</span></td>
                  <td><span className="check">✓</span></td>
                  <td><span className="cross">✗</span></td>
                </tr>
                <tr>
                  <td>Real-time cross-platform sync (your devices)</td>
                  <td className="highlight-col"><span className="check">✓ Free</span></td>
                  <td><span className="partial">Partial</span></td>
                  <td><span className="cross">Apple only</span></td>
                  <td><span className="check">✓</span></td>
                </tr>
                <tr>
                  <td>Multi-user note sharing & collaboration</td>
                  <td className="highlight-col"><span className="check">✓ Premium</span></td>
                  <td><span className="partial">Lists only</span></td>
                  <td><span className="cross">✗</span></td>
                  <td><span className="check">✓</span></td>
                </tr>
                <tr>
                  <td>Dedicated Brain Dump (text, voice & images)</td>
                  <td className="highlight-col"><span className="check">✓ Premium</span></td>
                  <td><span className="cross">✗</span></td>
                  <td><span className="cross">✗</span></td>
                  <td><span className="cross">✗</span></td>
                </tr>
                <tr>
                  <td>AI proofread & tone rewrite</td>
                  <td className="highlight-col"><span className="check">✓ Premium</span></td>
                  <td><span className="cross">✗</span></td>
                  <td><span className="cross">✗</span></td>
                  <td><span className="check">✓</span></td>
                </tr>
                <tr>
                  <td>Note locking / password protection</td>
                  <td className="highlight-col"><span className="check">✓</span></td>
                  <td><span className="cross">✗</span></td>
                  <td><span className="check">✓</span></td>
                  <td><span className="cross">✗</span></td>
                </tr>
                <tr>
                  <td>Checklists</td>
                  <td className="highlight-col"><span className="check">✓</span></td>
                  <td><span className="check">✓</span></td>
                  <td><span className="check">✓</span></td>
                  <td><span className="check">✓</span></td>
                </tr>
                <tr>
                  <td>Free plan</td>
                  <td className="highlight-col"><span className="check">✓ (150 notes)</span></td>
                  <td><span className="check">✓</span></td>
                  <td><span className="check">✓</span></td>
                  <td><span className="check">✓</span></td>
                </tr>
              </tbody>
            </table>
          </div>
          <div className="comparison-links">
            <a href="/compare/google-keep-vs-apple-notes">Google Keep vs Apple Notes →</a>
            <a href="/compare/google-keep-vs-notion">Google Keep vs Notion →</a>
            <a href="/compare/notion-vs-evernote">Notion vs Evernote →</a>
          </div>
        </section>

        {/* Testimonials Section */}
        <section id="testimonials" className="testimonials-section">
          <div className="testimonials-header">
            <h2>What people are saying</h2>
          </div>
          
          <div className="marquee-container">
            {[...TESTIMONIALS, ...TESTIMONIALS].map((testimonial, i) => (
              <div key={i} className="testimonial-card">
                <div className="testimonial-stars">
                  {Array.from({ length: 5 }).map((_, starIdx) => (
                    <Star 
                      key={starIdx} 
                      size={14} 
                      className={starIdx < testimonial.stars ? "star-filled" : "star-empty"} 
                      fill={starIdx < testimonial.stars ? "currentColor" : "none"} 
                    />
                  ))}
                </div>
                <p className="testimonial-text">"{testimonial.text}"</p>
                <div className="testimonial-author">
                  <div className="author-avatar">{testimonial.avatar}</div>
                  <div className="author-info">
                    <h4>{testimonial.author}</h4>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* FAQ Section */}
        <section id="faq" className="faq-section container">
          <div className="section-header">
            <h2>Frequently asked questions</h2>
            <p>Everything you need to know about InkSync.</p>
          </div>
          <div className="faq-list">
            {FAQ_ITEMS.map((item, index) => (
              <div key={index} className={`faq-item ${openFaq === index ? 'open' : ''}`}>
                <button 
                  className="faq-question" 
                  onClick={() => setOpenFaq(openFaq === index ? null : index)}
                  aria-expanded={openFaq === index}
                >
                  <span>{item.question}</span>
                  <ChevronDown className="faq-chevron" size={20} />
                </button>
                <div className="faq-answer">
                  <p>{item.answer}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Pricing Section */}
        <section id="pricing" className="pricing-section container">
          <div className="section-header">
            <h2>Simple, transparent pricing</h2>
            <p>Start free. Upgrade when you need more.</p>
          </div>
          <div className="pricing-cards">
            <div className="pricing-card">
              <div className="pricing-card-header">
                <h3>Free</h3>
                <div className="pricing-price">
                  <span className="price-amount">$0</span>
                  <span className="price-period">forever</span>
                </div>
              </div>
              <ul className="pricing-features">
                <li><span className="check">✓</span> Up to 150 notes & checklists</li>
                <li><span className="check">✓</span> Real-time cross-platform sync (your devices)</li>
                <li><span className="check">✓</span> Local-first offline access</li>
                <li><span className="check">✓</span> Tags & instant search</li>
                <li><span className="check">✓</span> Color-coded notebooks</li>
              </ul>
              <a href="https://app.inksyncnote.com/register" className="btn-outline pricing-btn">Get Started Free</a>
            </div>
            <div className="pricing-card pricing-card-featured">
              <div className="pricing-badge">Most Popular</div>
              <div className="pricing-card-header">
                <h3>Premium</h3>
                <div className="pricing-price">
                  <span className="price-amount">.99¢</span>
                  <span className="price-period">/week or $33.99/yr</span>
                </div>
              </div>
              <ul className="pricing-features">
                <li><span className="check">✓</span> <strong>Unlimited notes</strong></li>
                <li><span className="check">✓</span> Everything in Free</li>
                <li><span className="check">✓</span> Dedicated Brain Dump (voice, text & images)</li>
                <li><span className="check">✓</span> Multi-user note sharing & collaboration</li>
                <li><span className="check">✓</span> AI proofreading & tone rewriting</li>
                <li><span className="check">✓</span> Password-protected notes</li>
                <li><span className="check">✓</span> Calendar integration</li>
              </ul>
              <a href="https://app.inksyncnote.com/register" className="btn-primary pricing-btn">Start Free Trial</a>
            </div>
          </div>
        </section>

        {/* CTA Section */}
        <section id="download" className="cta-section">
          <div className="container">
            <div className="cta-box glass-panel">
              <h2>Ready to simplify your notes?</h2>
              <p>Start writing, organizing, and sharing — for free, across all your devices.</p>
              <a href="https://app.inksyncnote.com/register" className="btn-primary btn-large cta-btn">
                Create Your Free Account
              </a>
              <p className="cta-microcopy">Free forever • No credit card required</p>
              <div className="cta-store-buttons">
                <div className="store-btn store-btn-disabled" title="Coming Soon">
                  <AppleLogo size={28} />
                  <div className="store-text">
                    <span>Coming soon on the</span>
                    <strong>App Store</strong>
                  </div>
                </div>
                <a href={PLAY_STORE_URL} className="store-btn" target="_blank" rel="noopener noreferrer">
                  <GooglePlayLogo size={28} />
                  <div className="store-text">
                    <span>GET IT ON</span>
                    <strong>Google Play</strong>
                  </div>
                </a>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="footer container">
        <div className="footer-grid footer-grid-5">
          <div className="footer-brand">
            <div className="brand" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div className="logo-icon" style={{ width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <img src="/logo.png" alt="InkSync Logo" style={{ width: 18, height: 18, objectFit: 'contain' }} />
              </div>
              <span className="brand-text" style={{ fontSize: '20px', fontWeight: 700 }}>InkSync</span>
            </div>
            <p>Simple, cross-platform note-taking that syncs everywhere.</p>
          </div>
          <div className="footer-column">
            <h4>Product</h4>
            <a href="#features">Features</a>
            <a href="#pricing">Pricing</a>
            <a href="#faq">FAQ</a>
            <a href="#download">Download</a>
          </div>
          <div className="footer-column">
            <h4>Compare</h4>
            <a href="/compare/google-keep-vs-apple-notes">Keep vs Apple Notes</a>
            <a href="/compare/google-keep-vs-notion">Keep vs Notion</a>
            <a href="/compare/notion-vs-evernote">Notion vs Evernote</a>
            <a href="/compare/apple-notes-vs-notion">Apple Notes vs Notion</a>
          </div>
          <div className="footer-column">
            <h4>Alternatives</h4>
            <a href="/alternative/google-keep-alternative">Google Keep Alternative</a>
            <a href="/alternative/apple-notes-alternative">Apple Notes Alternative</a>
            <a href="/alternative/notion-alternative">Notion Alternative</a>
            <a href="/alternative/evernote-alternative">Evernote Alternative</a>
          </div>
          <div className="footer-column">
            <h4>Get Started</h4>
            <a href={`${APP_URL}/register`}>Create Account</a>
            <a href={`${APP_URL}/login`}>Sign In</a>
            <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer">Google Play</a>
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
