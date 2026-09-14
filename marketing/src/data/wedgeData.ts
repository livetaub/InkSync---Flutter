import {
  ShoppingCart,
  Users,
  WifiOff,
  Bell,
  Heart,
  Home,
  Plane,
  CalendarCheck,
  Lock,
  Zap,
  CheckSquare,
  Smartphone,
} from 'lucide-react';

export interface WedgeUseCase {
  title: string;
  description: string;
  icon: any;
}

export interface WedgeStep {
  title: string;
  description: string;
}

export interface WedgeFaq {
  question: string;
  answer: string;
}

export interface WedgeData {
  slug: string;
  breadcrumb: string;
  metaTitle: string;
  metaDescription: string;
  heroTitle: string;
  heroSubtitle: string;
  useCases: WedgeUseCase[];
  useCasesHeading: string;
  stepsHeading: string;
  steps: WedgeStep[];
  faqs: WedgeFaq[];
  ctaHeading: string;
  ctaSubtext: string;
}

const SHARE_CTA = 'https://app.inksyncnote.com';

export { SHARE_CTA };

export const wedgeData: WedgeData[] = [
  {
    slug: 'shared-grocery-list-app',
    breadcrumb: 'Shared Grocery List App',
    metaTitle: 'Shared Grocery List App for the Whole Family — InkSync',
    metaDescription:
      'One grocery list the whole family shares in real time. Add items from the couch, check them off at the store. Free to try on Android, iOS & web.',
    heroTitle: 'One grocery list the whole family actually shares',
    heroSubtitle:
      "Stop texting 'we need milk' back and forth. InkSync keeps a single shared list that updates on everyone's phone the second anyone changes it — at home, at work, or in the cereal aisle.",
    useCasesHeading: 'Built for the way families really shop',
    useCases: [
      {
        title: 'Real-time sync for everyone',
        description:
          'Add "eggs" from the couch and it appears on your partner\'s phone instantly. No refresh, no resend, no "did you get my text?".',
        icon: Zap,
      },
      {
        title: 'Check off items at the store',
        description:
          'Clean checklists with satisfying check-offs. When one person grabs the milk, everyone sees it crossed out — no more duplicate gallons.',
        icon: CheckSquare,
      },
      {
        title: 'Works without signal',
        description:
          'Stores have dead zones. InkSync saves everything on your device first and syncs when you reconnect, so your list never disappears mid-aisle.',
        icon: WifiOff,
      },
      {
        title: 'Invite the whole household',
        description:
          'Invite your partner, kids, or roommates by email. Everyone edits the same list, and you control who can change what.',
        icon: Users,
      },
    ],
    stepsHeading: 'From fridge to checkout in three steps',
    steps: [
      {
        title: 'Create your grocery list',
        description:
          'Open InkSync, start a checklist, and type what you need. Add quantities and notes like "the oat kind, not dairy".',
      },
      {
        title: 'Invite your family',
        description:
          'Share the list with your household by email. They join in seconds — no complicated setup, no IT department required.',
      },
      {
        title: 'Shop in sync',
        description:
          'Everyone adds items through the week and checks them off at the store. One list, always current, zero duplicate purchases.',
      },
    ],
    faqs: [
      {
        question: 'Is InkSync free?',
        answer:
          'Yes — the free plan includes up to 50 notes and checklists with real-time sync across your devices. Shared lists and multi-user collaboration are Premium features, at $0.99 per week or $33.99 per year.',
      },
      {
        question: 'How do I share a grocery list with my family?',
        answer:
          'Create a checklist in InkSync, tap share, and invite your family members by email. They can view and edit the list in real time from their own phones.',
      },
      {
        question: 'Does it work on both iPhone and Android?',
        answer:
          'InkSync is live on Android via Google Play and on the web at app.inksyncnote.com, which works great on iPhone browsers. A native iOS app is coming soon.',
      },
      {
        question: 'What if the grocery store has no cell signal?',
        answer:
          'InkSync is offline-first: your list is saved on your device, so it works with zero bars. Changes sync automatically when you reconnect.',
      },
      {
        question: 'How is this different from sharing a list in Google Keep?',
        answer:
          'Google Keep sharing is basic and tied to Google accounts. InkSync is built for sharing from the ground up — real-time collaboration, per-person permissions, checklists that stay in sync, and AI tools to tidy up messy lists.',
      },
    ],
    ctaHeading: 'Never buy two gallons of milk again',
    ctaSubtext:
      'Set up your first shared grocery list in under a minute. Free to try.',
  },
  {
    slug: 'notes-app-for-couples',
    breadcrumb: 'Notes App for Couples',
    metaTitle: 'Notes App for Couples — Share Lists & Notes | InkSync',
    metaDescription:
      'Grocery lists, date-night ideas, trip plans — one shared space where you and your partner stay in sync. Free to try on Android, iOS & web.',
    heroTitle: 'A notes app made for two',
    heroSubtitle:
      'Grocery lists, date-night ideas, trip plans, little reminders — one shared space where you and your partner stay in sync, without the group-chat chaos.',
    useCasesHeading: 'Everything couples share, in one place',
    useCases: [
      {
        title: 'Shared grocery & to-do lists',
        description:
          'The classic couple use case, done right. One list, both phones, always current — from "we\'re out of coffee" to checked off.',
        icon: ShoppingCart,
      },
      {
        title: 'Date nights & trip plans',
        description:
          'Keep a running list of restaurants to try, movies to watch, and weekend getaways to plan — together.',
        icon: Heart,
      },
      {
        title: 'Reminders that reach both of you',
        description:
          'Appointment times, gift ideas, anniversary plans. Write it once, and you both have it wherever you are.',
        icon: Bell,
      },
      {
        title: 'Private by default',
        description:
          'Your shared notes are visible only to the people you invite. Lock sensitive notes with a password for extra privacy.',
        icon: Lock,
      },
    ],
    stepsHeading: 'Sharing with your partner takes seconds',
    steps: [
      {
        title: 'Create a note or list',
        description:
          'Start anything — a grocery list, a packing checklist, a note full of date-night ideas.',
      },
      {
        title: 'Invite your partner',
        description:
          'Share it by email. They see it instantly and can edit alongside you in real time.',
      },
      {
        title: 'Stay in sync',
        description:
          'Changes appear on both phones the moment they happen. No screenshots of lists, no "remind me later" texts.',
      },
    ],
    faqs: [
      {
        question: 'How do we share notes as a couple?',
        answer:
          'Create any note or checklist in InkSync and invite your partner by email. You can both view and edit it in real time, each from your own phone.',
      },
      {
        question: 'Can we both edit the same note at the same time?',
        answer:
          'Yes. InkSync supports real-time collaboration — edits from both of you merge live, so you never overwrite each other.',
      },
      {
        question: 'Is our shared content private?',
        answer:
          'Completely. Shared notes are visible only to the people you explicitly invite, and you can password-lock individual notes for sensitive information.',
      },
      {
        question: 'Is InkSync free for couples?',
        answer:
          'The free plan includes up to 50 notes and checklists. Sharing and real-time collaboration are Premium features at $0.99 per week or $33.99 per year — one subscription covers the sharing you both use.',
      },
      {
        question: 'Does it work if one of us has an iPhone and the other has Android?',
        answer:
          'Yes. InkSync is cross-platform: native Android app, web app that works on iPhone browsers, and a native iOS app coming soon. Your notes sync across all of them.',
      },
    ],
    ctaHeading: 'Your second brain, shared with your favorite person',
    ctaSubtext:
      'Create your first shared note together tonight. Free to try.',
  },
  {
    slug: 'family-shared-notes-app',
    breadcrumb: 'Family Shared Notes App',
    metaTitle: 'Family Shared Notes App — One Hub for Home | InkSync',
    metaDescription:
      'Chores, shopping, school reminders, vacation plans — every shared note your household needs, synced in real time. Free to try.',
    heroTitle: "The family's shared brain",
    heroSubtitle:
      'Chores, shopping lists, school reminders, vacation plans — every shared note and list your household needs, synced to everyone\'s phone the moment it changes.',
    useCasesHeading: 'Run the household from one app',
    useCases: [
      {
        title: 'Household hub',
        description:
          'Wi-Fi passwords, plumber numbers, school schedules — the info everyone asks for, finally in one findable place.',
        icon: Home,
      },
      {
        title: 'Chores & tasks',
        description:
          'Shared checklists for weekly chores, home projects, and holiday prep. Everyone sees what\'s done and what\'s left.',
        icon: CalendarCheck,
      },
      {
        title: 'Trip & event planning',
        description:
          'Packing lists, itineraries, and "don\'t forget" notes the whole family can add to before the big trip.',
        icon: Plane,
      },
      {
        title: 'On every device',
        description:
          'Android phones, iPhones via the web app, laptops — the family stays in sync no matter what everyone carries.',
        icon: Smartphone,
      },
    ],
    stepsHeading: 'Get the household on the same page',
    steps: [
      {
        title: 'Create shared notes',
        description:
          'Set up the lists your family actually needs: groceries, chores, school info, vacation plans.',
      },
      {
        title: 'Invite everyone',
        description:
          'Add family members by email. Each person gets the notes on their own phone — no shared logins.',
      },
      {
        title: 'Stay effortlessly synced',
        description:
          'When plans change, change the note once. The whole family sees it instantly — no family-group-chat archaeology.',
      },
    ],
    faqs: [
      {
        question: 'How many family members can share notes?',
        answer:
          'Invite as many family members as you like by email. Each person has their own InkSync account, and you control who can view or edit each shared note.',
      },
      {
        question: 'Can I share notes with my kids?',
        answer:
          'Yes. Create a free InkSync account for each family member and invite them to the notes you want to share — like chore checklists or packing lists.',
      },
      {
        question: 'What does the free plan include?',
        answer:
          'The free plan includes up to 50 notes and checklists with real-time sync. Family sharing and collaboration are Premium features at $0.99 per week or $33.99 per year.',
      },
      {
        question: 'Does it work offline?',
        answer:
          'Yes. InkSync saves everything on-device first, so notes and lists work without internet and sync when you reconnect.',
      },
      {
        question: 'Can I keep some notes private from the family?',
        answer:
          'Absolutely. Only notes you explicitly share are visible to others, and you can password-lock any individual note.',
      },
    ],
    ctaHeading: 'One app the whole family actually opens',
    ctaSubtext:
      'Set up your household hub today. Free to try, no credit card required.',
  },
];
