import {
  AlertTriangle,
  Lock,
  Smartphone,
  Globe,
  Feather,
  Users,
  CheckSquare,
  Zap,
  Layout,
  DollarSign,
  CloudOff,
  Briefcase,
  Clock,
  WifiOff
} from 'lucide-react';

export interface PainPoint {
  title: string;
  description: string;
  icon: any; // We'll pass the lucide component directly or mapped
}

export interface AlternativeFeature {
  feature: string;
  competitor: string | boolean;
  inksync: string | boolean;
}

export interface AlternativeData {
  slug: string;
  competitorName: string;
  metaTitle: string;
  metaDescription: string;
  heroTitle: string;
  heroSubtitle: string;
  painPoints: PainPoint[];
  solutions: { title: string; description: string; icon: any }[];
  features: AlternativeFeature[];
  switchQuote: string;
}

export const alternativesData: AlternativeData[] = [
  {
    slug: 'google-keep-alternative',
    competitorName: 'Google Keep',
    metaTitle: 'Best Google Keep Alternative in 2026 — InkSync',
    metaDescription: 'Looking for a Google Keep alternative? InkSync offers true real-time collaboration, privacy features, and AI writing tools without locking you into the Google ecosystem.',
    heroTitle: 'Looking for a Google Keep alternative?',
    heroSubtitle: 'Break free from the Google ecosystem. InkSync offers the simplicity you love with the powerful collaboration and privacy features you need.',
    painPoints: [
      {
        title: 'Locked in the Ecosystem',
        description: 'Google Keep works best only when you are deeply entrenched in the Google ecosystem.',
        icon: AlertTriangle
      },
      {
        title: 'No Real Collaboration',
        description: 'Sharing notes is clunky and lacks true real-time collaborative editing features.',
        icon: Users
      },
      {
        title: 'No AI Writing Tools',
        description: 'No built-in AI to help you summarize, rewrite, or brainstorm. You\'re on your own for every draft.',
        icon: Feather
      },
      {
        title: 'No Note Privacy',
        description: 'You cannot lock individual notes with a PIN or password for sensitive information.',
        icon: Lock
      }
    ],
    solutions: [
      {
        title: 'True Cross-Platform',
        description: 'Works seamlessly on Android, iOS, Windows, Mac, and Web. You are never locked in.',
        icon: Globe
      },
      {
        title: 'Real-Time Collab',
        description: 'Edit notes together in real-time, just like Google Docs, but built for quick notes.',
        icon: Users
      },
      {
        title: 'AI Writing Tools',
        description: 'Built-in AI to summarize, expand, or rewrite your notes instantly.',
        icon: Zap
      },
      {
        title: 'Note Locking',
        description: 'Secure your sensitive notes with PIN or biometric authentication.',
        icon: Lock
      }
    ],
    features: [
      { feature: 'Multi-User Note Sharing & Collaboration', competitor: false, inksync: 'Premium' },
      { feature: 'Real-time Cross-Platform Sync', competitor: true, inksync: 'Free (150 notes)' },
      { feature: 'AI Writing Assistant', competitor: false, inksync: 'Premium' },
      { feature: 'Note Locking/Privacy', competitor: false, inksync: true },
      { feature: 'Checklists', competitor: false, inksync: true },
      { feature: 'Works without Google Account', competitor: false, inksync: true }
    ],
    switchQuote: 'Stop settling for basic post-it notes. Upgrade to a modern workspace.'
  },
  {
    slug: 'apple-notes-alternative',
    competitorName: 'Apple Notes',
    metaTitle: 'Best Apple Notes Alternative in 2026 — InkSync',
    metaDescription: 'Leave Apple Notes behind. InkSync is the cross-platform alternative that works on Android, Web, and iOS with AI tools and easy sharing with non-Apple users.',
    heroTitle: 'Looking for an Apple Notes alternative?',
    heroSubtitle: 'Stop being locked to Apple devices. InkSync gives you the polished, fast experience of Apple Notes on every platform, including Android and Web.',
    painPoints: [
      {
        title: 'Locked to Apple Devices',
        description: 'Want to check a note on a Windows PC or Android phone? The experience is terrible or non-existent.',
        icon: Smartphone
      },
      {
        title: 'Collaboration is a Hassle',
        description: 'Try collaborating with a non-Apple user. It is frustrating and limits who you can work with.',
        icon: Users
      },
      {
        title: 'No AI Assistance',
        description: 'Apple Notes lacks modern AI writing tools to help you draft, summarize, or fix grammar.',
        icon: Zap
      }
    ],
    solutions: [
      {
        title: 'Works on Every Platform',
        description: 'Native apps for iOS and Android, plus a beautiful web app for Windows and Linux users with free device sync.',
        icon: Globe
      },
      {
        title: 'Collaborate with Anyone',
        description: 'Share a note and collaborate in real-time with Premium. No specific device or ecosystem required.',
        icon: Users
      },
      {
        title: 'Smart AI Tools',
        description: 'Generate ideas, summarize meetings, or format text with just one tap using InkSync AI.',
        icon: Zap
      }
    ],
    features: [
      { feature: 'Native Android App', competitor: false, inksync: true },
      { feature: 'Multi-User Note Sharing & Collaboration', competitor: false, inksync: 'Premium' },
      { feature: 'Real-time Cross-Platform Sync', competitor: 'Apple only', inksync: 'Free (150 notes)' },
      { feature: 'Folder Organization', competitor: true, inksync: true },
      { feature: 'AI Writing Assistant', competitor: false, inksync: 'Premium' },
      { feature: 'Document Scanning', competitor: true, inksync: true },
      { feature: 'Device Agnostic', competitor: false, inksync: true }
    ],
    switchQuote: 'Break free from device lock-in. Access and edit your notes anywhere.'
  },
  {
    slug: 'notion-alternative',
    competitorName: 'Notion',
    metaTitle: 'Best Notion Alternative for Quick Notes in 2026 — InkSync',
    metaDescription: 'Notion is great for databases, but too slow for quick thoughts. InkSync is the fast, plain-text note app built for speed.',
    heroTitle: 'Looking for a simpler Notion alternative?',
    heroSubtitle: 'Notion is powerful, but it takes forever to open on mobile. InkSync is lightning fast, local-first, and designed for quick capture.',
    painPoints: [
      {
        title: 'Slow to Open',
        description: 'Waiting 5 seconds for a database block to load means you lose fleeting thoughts before writing them down.',
        icon: Clock
      },
      {
        title: 'Overwhelming Complexity',
        description: 'You want to write a grocery list, but end up spending 20 minutes setting up properties and databases.',
        icon: AlertTriangle
      },
      {
        title: 'Poor Offline Mode',
        description: 'Without an internet connection, Notion often locks you out of viewing or editing your pages.',
        icon: WifiOff
      }
    ],
    solutions: [
      {
        title: 'Simple and Fast',
        description: 'Open the app and start typing. No blocks, no databases, just a clean interface for your thoughts.',
        icon: Zap
      },
      {
        title: 'Built for Mobile',
        description: 'Lightning-fast native mobile apps designed to capture ideas the second they happen with local-first storage.',
        icon: Smartphone
      },
      {
        title: 'Affordable Premium',
        description: 'Generous free tier (up to 150 notes & checklists), and starting at just .99¢/wk or $33.99/yr for Premium with unlimited notes.',
        icon: DollarSign
      }
    ],
    features: [
      { feature: 'Fast Mobile App', competitor: 'Slow', inksync: 'Lightning Fast' },
      { feature: 'Learning Curve', competitor: 'Steep', inksync: 'None' },
      { feature: 'Offline Mode', competitor: 'Limited', inksync: 'Local-first (100% Offline)' },
      { feature: 'Dedicated Brain Dump (voice, text & images)', competitor: false, inksync: 'Premium' },
      { feature: 'Multi-User Note Sharing & Collaboration', competitor: true, inksync: 'Premium' },
      { feature: 'AI Proofread & Tone Rewrite', competitor: true, inksync: 'Premium' },
      { feature: 'Starting Price (Paid)', competitor: '$10/mo', inksync: '.99¢/wk or $33.99/yr' }
    ],
    switchQuote: 'Spend your time writing notes, not organizing databases.'
  },
  {
    slug: 'simplenote-alternative',
    competitorName: 'Simplenote',
    metaTitle: 'Best Simplenote Alternative in 2026 — InkSync',
    metaDescription: 'Love Simplenote but need more? InkSync adds checklists, Brain Dump, AI tools, and multi-user collaboration while keeping simplicity.',
    heroTitle: 'Looking for a more powerful Simplenote alternative?',
    heroSubtitle: 'Keep the speed and simplicity, but gain modern features like checklists, Brain Dump, AI writing, and multi-user collaboration.',
    painPoints: [
      {
        title: 'Plain Text Only',
        description: 'No ability to create proper checklists, bold text, or structure your notes visually.',
        icon: Feather
      },
      {
        title: 'No Collaboration',
        description: 'You cannot work on a note with someone else at the same time.',
        icon: Users
      },
      {
        title: 'Minimal Organization',
        description: 'Relying purely on tags gets messy. No folders, color-coding, or smart organization.',
        icon: Layout
      }
    ],
    solutions: [
      {
        title: 'Interactive Checklists',
        description: 'Create interactive checklists with checkboxes that actually work — perfect for to-dos and shopping lists.',
        icon: CheckSquare
      },
      {
        title: 'Multi-User Collaboration',
        description: 'Share a note and see your friends or colleagues typing in real-time with Premium.',
        icon: Users
      },
      {
        title: 'Smart Organization',
        description: 'Use tags and color-coding to keep everything perfectly organized.',
        icon: Briefcase
      }
    ],
    features: [
      { feature: 'Speed & Simplicity', competitor: true, inksync: true },
      { feature: 'Real-time Cross-Platform Sync', competitor: true, inksync: 'Free (150 notes)' },
      { feature: 'Checklists', competitor: false, inksync: true },
      { feature: 'Dedicated Brain Dump (voice, text & images)', competitor: false, inksync: 'Premium' },
      { feature: 'Multi-User Note Sharing & Collaboration', competitor: false, inksync: 'Premium' },
      { feature: 'AI Writing Assistant', competitor: false, inksync: 'Premium' },
      { feature: 'Color-coded Notes', competitor: false, inksync: true }
    ],
    switchQuote: 'It is time to add a little color and structure to your notes.'
  },
  {
    slug: 'bear-alternative',
    competitorName: 'Bear',
    metaTitle: 'Best Bear Alternative for Android & Web in 2026 — InkSync',
    metaDescription: 'Love Bear but use Android or Windows? InkSync offers a beautiful, fast note-taking experience across all platforms with free syncing.',
    heroTitle: 'Looking for a Bear alternative for all devices?',
    heroSubtitle: 'Bear is beautiful, but it leaves non-Apple users in the dark. InkSync brings premium, aesthetic note-taking to Android, Web, and beyond.',
    painPoints: [
      {
        title: 'Apple-Only',
        description: 'If you switch to Android or use a Windows PC for work, you lose access to all your notes.',
        icon: Globe
      },
      {
        title: 'Paid Syncing',
        description: 'You have to pay a subscription just to sync your notes between your own devices.',
        icon: DollarSign
      },
      {
        title: 'No Collaboration',
        description: 'Bear is strictly a solo experience. You cannot share and edit notes with others.',
        icon: Users
      }
    ],
    solutions: [
      {
        title: 'Every Platform Supported',
        description: 'Native Android app, beautiful Web app, iOS, Windows, Mac. It works everywhere you do.',
        icon: Smartphone
      },
      {
        title: 'Free Device Sync',
        description: 'Syncing your notes across all your devices is completely free on InkSync (up to 150 notes & checklists).',
        icon: CloudOff
      },
      {
        title: 'Multi-User Collaboration',
        description: 'Easily share your notes and collaborate with anyone using Premium, no matter what device they use.',
        icon: Users
      }
    ],
    features: [
      { feature: 'Markdown Support', competitor: true, inksync: true },
      { feature: 'Beautiful UI', competitor: true, inksync: true },
      { feature: 'Android App', competitor: false, inksync: true },
      { feature: 'Web App', competitor: false, inksync: true },
      { feature: 'Real-time Cross-Platform Sync', competitor: 'Paid ($2.99/mo)', inksync: 'Free (150 notes)' },
      { feature: 'Dedicated Brain Dump', competitor: false, inksync: 'Premium' },
      { feature: 'Multi-User Note Sharing & Collaboration', competitor: false, inksync: 'Premium' }
    ],
    switchQuote: 'Beautiful notes should be accessible on every screen you own.'
  },
  {
    slug: 'evernote-alternative',
    competitorName: 'Evernote',
    metaTitle: 'Best Evernote Alternative in 2026 — InkSync',
    metaDescription: 'Tired of Evernote price hikes and bloat? InkSync is the fast, affordable, and modern alternative for note-takers who want simplicity.',
    heroTitle: 'Looking for an Evernote alternative?',
    heroSubtitle: 'Escape the bloat and endless price hikes. InkSync is fast, modern, and perfectly priced for individuals who just want to write.',
    painPoints: [
      {
        title: 'Too Expensive',
        description: 'At $14.99/month or more, Evernote has become incredibly expensive for personal use.',
        icon: DollarSign
      },
      {
        title: 'Bloated and Slow',
        description: 'The app has become heavy with features you do not use, making basic note-taking slow.',
        icon: Layout
      },
      {
        title: 'Limited Free Tier',
        description: 'The free plan is extremely restrictive, making it nearly impossible to use long-term.',
        icon: AlertTriangle
      }
    ],
    solutions: [
      {
        title: 'Affordable Pricing',
        description: 'InkSync Premium is just .99¢/wk ($33.99/yr) for unlimited notes, and our free tier is generous enough for most users.',
        icon: DollarSign
      },
      {
        title: 'Fast and Clean',
        description: 'A modern, lightweight app that opens instantly with local-first storage and focuses on writing.',
        icon: Zap
      },
      {
        title: 'Generous Free Plan',
        description: 'Create up to 150 notes & checklists with cross-device sync on our free plan. No paywall traps.',
        icon: CheckSquare
      }
    ],
    features: [
      { feature: 'Web Clipper', competitor: true, inksync: false },
      { feature: 'Real-time Cross-Platform Sync', competitor: 'Paid only (mostly)', inksync: 'Free (150 notes)' },
      { feature: 'App Speed', competitor: 'Slow & Heavy', inksync: 'Lightning Fast' },
      { feature: 'Dedicated Brain Dump', competitor: false, inksync: 'Premium' },
      { feature: 'AI Proofreading & Tone Rewrite', competitor: true, inksync: 'Premium' },
      { feature: 'Multi-User Note Sharing & Collaboration', competitor: true, inksync: 'Premium' },
      { feature: 'Starting Paid Price', competitor: '$14.99+/mo', inksync: '.99¢/wk ($33.99/yr)' }
    ],
    switchQuote: 'Go back to basics. Get a fast, clean note-taking app that doesn\'t break the bank.'
  }
];
