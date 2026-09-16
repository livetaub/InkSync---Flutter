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

export interface WedgeRelatedLink {
  label: string;
  url: string;
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
  relatedLinks: WedgeRelatedLink[];
}

const SHARE_CTA = 'https://app.inksyncnote.com';

export { SHARE_CTA };

export const wedgeData: WedgeData[] = [
  {
    slug: 'shared-grocery-list-app',
    breadcrumb: 'Shared Grocery List App',
    metaTitle: 'Shared Grocery List App for Families — InkSync',
    metaDescription:
      'Shared grocery list app the whole family edits in real time. Add from the couch, check off in dead-zone aisles. Free to try — Android & web.',
    heroTitle: 'Shared Grocery List App for the Whole Family',
    heroSubtitle:
      'Stop texting “we need milk” back and forth across the week. InkSync gives your household one shared grocery list that updates on every phone the instant anyone changes it — from the couch, from the office, or standing in the cereal aisle with zero bars.',
    useCasesHeading: 'Built for the way families really shop',
    useCases: [
      {
        title: 'Real-time sync for everyone',
        description:
          'Add “eggs” from the couch and it appears on your partner’s phone before you’ve put your own phone down. No refresh button, no forwarding screenshots of a list, no “did you get my text?” — one shared grocery list that is simply always current on every screen in the house.',
        icon: Zap,
      },
      {
        title: 'Check off items at the store',
        description:
          'Turn the list into a checklist and tap items off as they land in the cart. When you grab the milk, everyone watching the list sees it crossed out — so your partner doesn’t pick up a second gallon “just in case.” The weekly shop stops being a guessing game.',
        icon: CheckSquare,
      },
      {
        title: 'Works without signal',
        description:
          'Supermarket dead zones are real — concrete walls, basement-level stores, rural shops. InkSync is local-first: the full list lives on your device, so it opens and updates with zero bars. The moment you’re back in signal, everything syncs and your family sees what you bought.',
        icon: WifiOff,
      },
      {
        title: 'Invite the whole household',
        description:
          'Share the list by email with your partner, kids, or roommates — everyone gets their own account and edits the same list in real time. You control who’s invited, so the grocery list never accidentally includes your group chat from work.',
        icon: Users,
      },
      {
        title: 'The weekly shop, planned together',
        description:
          'Sunday-night meal planning stops being one person’s chore. Draft the week’s dinners in a note, turn it into a shopping checklist, and let everyone add what they want — snacks for the kids’ lunches, coffee for the early riser. The list builds itself all week.',
        icon: ShoppingCart,
      },
      {
        title: 'Capture it the moment you notice',
        description:
          'You’re out of olive oil — add it to the list from the kitchen, from the car, or from your desk at work. Kids can add their own snack requests instead of yelling them down the hall. By Saturday, the list is complete because nobody had to “remember to write it down later.”',
        icon: Bell,
      },
      {
        title: 'Roommates stay coordinated too',
        description:
          'Not every household is a family. Split the shop with roommates: everyone adds what they need, checks off what they’ve bought, and the list settles the eternal “who was supposed to get toilet paper?” debate. Shared staples live on a running list; personal items stay yours.',
        icon: Home,
      },
    ],
    stepsHeading: 'From fridge to checkout in five steps',
    steps: [
      {
        title: 'Create your grocery list',
        description:
          'Open InkSync and start a checklist for this week’s shop — or keep one permanent “groceries” list you reuse every week. Add items with quantities and little notes like “the oat kind, not dairy” so whoever shops buys exactly the right thing.',
      },
      {
        title: 'Invite your family',
        description:
          'Tap share and invite your household by email. Each person joins with their own InkSync account — on Android via the Play Store app, or on any phone through the web app — and the list lands on their phone in seconds. No shared logins, no family IT project.',
      },
      {
        title: 'Keep a running list all week',
        description:
          'Don’t wait for shopping day. The moment someone finishes the last of something, they add it to the shared list — from the kitchen, the office, or the school pickup line. By the weekend, the list is already complete and nobody has to reconstruct the week from memory.',
      },
      {
        title: 'Shop in sync, even with zero bars',
        description:
          'At the store, check items off as they go in the cart — everyone else sees it happen live. Concrete walls and basement aisles can’t break it: InkSync saves on-device first, so the list works with no signal and syncs the moment you reconnect.',
      },
      {
        title: 'Reset for next week',
        description:
          'After the shop, clear the checked items with one tap and keep the staples — milk, eggs, bread — sitting ready on the list. Next week’s shop starts half-written, and the family rhythm keeps running without anyone managing a spreadsheet.',
      },
    ],
    faqs: [
      {
        question: 'Is InkSync free?',
        answer:
          'The free plan covers up to 50 notes and checklists with real-time sync across your own devices — plenty for a personal grocery list. Sharing a list with your household and collaborating in real time are Premium features, at $0.99 per week or $33.99 per year for unlimited notes, invites, and AI tools.',
      },
      {
        question: 'How do I share a grocery list with my family?',
        answer:
          'Open the checklist, tap share, and invite each family member by email. They join with their own InkSync account — Android users grab the app from the Play Store, everyone else (including iPhone users) can use the web app at app.inksyncnote.com. Everyone edits the same list live, and changes appear on every phone within seconds.',
      },
      {
        question: 'Does it work on both iPhone and Android?',
        answer:
          'Yes. InkSync is live on Android through the Google Play Store, and the web app at app.inksyncnote.com works on any phone — iPhones included — plus tablets and laptops. Everything syncs across all of them. A native iOS app is on the way; meanwhile the web app is fully featured.',
      },
      {
        question: 'What if the grocery store has no cell signal?',
        answer:
          'You’re covered. InkSync is offline-first, so the whole list is saved on your device and works with zero bars — open it, add items, check things off. The moment your phone finds signal again, every change syncs to the rest of the family automatically. Nothing is ever stuck on one phone.',
      },
      {
        question: 'How is this different from a shared list in Google Keep?',
        answer:
          'Keep’s sharing is basic and tied to Google accounts — if your family isn’t all-in on Google, it gets awkward. InkSync is built for household sharing from the ground up: anyone joins by email, edits land in real time, checklists stay perfectly in sync, and the AI proofread tidies up messy “milk eggs bread???” entries. Plus it works offline in dead-zone stores.',
      },
      {
        question: 'Can everyone add items from different places at the same time?',
        answer:
          'Yes — that’s the whole point. You’re at work remembering the birthday cake, your partner’s at home seeing the empty fridge, the kids are requesting snacks — everyone adds to the same list at once, and every change lands on every phone in real time. No conflicts, no overwritten items.',
      },
      {
        question: 'What happens if someone accidentally deletes the list?',
        answer:
          'Shared lists belong to the person who created them, and only invited members can open them — so nothing is floating around publicly. If something gets deleted by mistake, you can re-create and re-share it in seconds, and everyone re-syncs. For extra safety, keep an unshared backup copy of your master grocery template.',
      },
    ],
    ctaHeading: 'Never buy two gallons of milk again',
    ctaSubtext:
      'Set up your first shared grocery list in under a minute — free to try on Android and the web.',
    relatedLinks: [
      {
        label: 'Google Keep vs Apple Notes',
        url: '/compare/google-keep-vs-apple-notes/',
      },
      {
        label: 'Best Google Keep alternative',
        url: '/alternative/google-keep-alternative/',
      },
      {
        label: 'Family Shared Notes App',
        url: '/family-shared-notes-app/',
      },
    ],
  },
  {
    slug: 'notes-app-for-couples',
    breadcrumb: 'Notes App for Couples',
    metaTitle: 'Notes App for Couples: Share Lists & Notes — InkSync',
    metaDescription:
      'Notes app for couples: shared grocery lists, date ideas, trip plans — one private space you both update in real time. Free to try.',
    heroTitle: 'Notes App for Couples',
    heroSubtitle:
      'Grocery lists, date-night ideas, packing lists, and the thousand tiny things a couple tracks — in one shared space you both see and both can edit, without forwarding screenshots or digging through months of chat history. It updates on both phones the instant either of you changes it.',
    useCasesHeading: 'Everything couples share, in one place',
    useCases: [
      {
        title: 'Shared grocery & to-do lists',
        description:
          'Start as roommates do and graduate: one grocery list that updates on both phones, a shared to-do list for the week, “pick up dry cleaning” notes that don’t get lost. From “we’re out of coffee” to checked off — without a single reminder text.',
        icon: ShoppingCart,
      },
      {
        title: 'Date nights & trip plans',
        description:
          'Keep a running “us” list: restaurants to try, movies to watch, weekend getaways to dream about. When the mood strikes, the ideas are already there — both of you adding, both of you voting with checkmarks. Spontaneity, minus the “what do you want to do?” loop.',
        icon: Heart,
      },
      {
        title: 'Reminders that reach both of you',
        description:
          'Doctor appointments, gift deadlines, the in-laws’ anniversary, “call the landlord about the sink.” Write it once and it’s on both phones — so the reminder doesn’t live and die in whoever happened to hear it first. Shared notes mean shared responsibility for remembering.',
        icon: Bell,
      },
      {
        title: 'Private by default',
        description:
          'Everything you share is visible only to the two of you — no public links, no strangers stumbling in. And for the genuinely sensitive stuff — finances, passwords, the surprise party plan — lock individual notes with a password so they stay yours alone even on a shared device.',
        icon: Lock,
      },
      {
        title: 'Split the household mental load',
        description:
          'Who paid the electric bill? Whose turn is laundry? What’s the plumber’s number? The invisible logistics of a shared life stop living in one person’s head. Put them in a shared note and you both always know — no “I thought you were handling that.”',
        icon: Home,
      },
      {
        title: 'Pack and plan trips together',
        description:
          'One shared note holds the whole trip: the itinerary, the packing checklists for both of you, the restaurant you both want to try. Add things from your desk while your partner adds from the couch — and check the packing list off together the night before.',
        icon: Plane,
      },
      {
        title: 'Your shared memory',
        description:
          'Gift ideas spotted in October, their coffee order, the name of that place you said you’d revisit “someday.” InkSync’s AI proofread can even tidy your quick, typo-ridden notes into something readable later. A couple’s shared brain beats a couple’s group chat every time.',
        icon: CalendarCheck,
      },
    ],
    stepsHeading: 'From note to shared in five steps',
    steps: [
      {
        title: 'Create a note or list',
        description:
          'Start anything — the grocery checklist, a packing list for the cabin weekend, a note full of date-night ideas, the Wi-Fi password you both keep forgetting. Personal notes stay yours until you decide to share them. If it’s just for you, it never leaves your account.',
      },
      {
        title: 'Invite your partner',
        description:
          'Tap share and send an invite to their email. They create their own free InkSync account — Android app from the Play Store, or the web app on iPhone and everything else — and your note appears on their phone within seconds. Two accounts, one shared note.',
      },
      {
        title: 'Edit together in real time',
        description:
          'Both of you can add, delete, and check things off at the same time — changes merge live, so you never overwrite each other. It’s the difference between sharing a note and actually collaborating: the list is simply always the latest version on both screens.',
      },
      {
        title: 'Keep the private stuff private',
        description:
          'Not everything is shared — and that’s by design. Your personal notes stay visible only to you, and anything truly sensitive gets a password lock. Share what helps the relationship run; keep what doesn’t. You choose, note by note. Simple as that.',
      },
      {
        title: 'Works everywhere you both are',
        description:
          'One of you on Android, one on iPhone, a laptop on the desk — it doesn’t matter. InkSync syncs across the Android app and the web app, works offline when the signal drops, and picks up right where you left off. Your shared life, on every screen.',
      },
    ],
    faqs: [
      {
        question: 'How do I invite my partner to share notes?',
        answer:
          'Open any note or checklist, tap share, and enter your partner’s email. They’ll get an invite, create their own free InkSync account, and the note appears on their phone ready to edit. It takes under a minute — no pairing codes, no shared passwords. Just the two of you, synced.',
      },
      {
        question: 'What does each person see?',
        answer:
          'Exactly the same shared note, updated live. When you check off “buy milk,” it crosses out on your partner’s phone too. Personal notes you never shared stay invisible to each other — sharing is always your choice, note by note, so nothing leaks by accident. Nothing syncs that you didn’t invite them to.',
      },
      {
        question: 'Do we both need the app and an account?',
        answer:
          'Each of you needs your own free InkSync account — that’s what keeps your personal notes separate and your shared notes in sync. You don’t need the same device: the Android app covers Android phones, and the web app at app.inksyncnote.com covers iPhones, tablets, and laptops. A native iOS app is coming soon.',
      },
      {
        question: 'Is InkSync free for couples, or do we need Premium?',
        answer:
          'The free plan gives each of you up to 50 notes with real-time sync — fine for trying things out. Sharing notes and collaborating in real time are Premium features: $0.99 per week or $33.99 per year — one subscription covers the sharing you both use. You get unlimited notes, invites, Brain Dump, and AI proofread with it.',
      },
      {
        question: 'What happens if we stop sharing a note?',
        answer:
          'Unsharing is as easy as sharing: remove your partner from the note and it disappears from their phone while staying intact on yours. Neither of you loses your own notes, and your personal unshared notes were never visible to begin with. Shared checklists revert to being just yours. Clean, no awkwardness.',
      },
      {
        question: 'Can we both edit the same note at the same time?',
        answer:
          'Yes. InkSync merges both of your edits in real time — you add “eggs” while your partner checks off “milk,” and the note simply shows the latest for both of you. No locking, no “someone else is editing” warnings, no lost changes when you’re both in a hurry. It just works.',
      },
      {
        question: 'Does it work if one of us has an iPhone and the other has Android?',
        answer:
          'Yes, mixed-device couples are the norm. The Android partner uses the Play Store app; the iPhone partner uses the web app at app.inksyncnote.com, which runs fully featured in the browser. Notes sync instantly between them, and a native iOS app is coming soon. Nobody needs to switch devices to stay in sync.',
      },
    ],
    ctaHeading: 'Your second brain, shared with your favorite person',
    ctaSubtext:
      'Create your first shared note together tonight — free to try, no credit card required.',
    relatedLinks: [
      {
        label: 'Family Shared Notes App',
        url: '/family-shared-notes-app/',
      },
      {
        label: 'Apple Notes vs Evernote',
        url: '/compare/apple-notes-vs-evernote/',
      },
    ],
  },
  {
    slug: 'family-shared-notes-app',
    breadcrumb: 'Family Shared Notes App',
    metaTitle: 'Family Shared Notes App — One Hub | InkSync',
    metaDescription:
      'Family shared notes app: chores, school info, packing lists and emergency contacts in one synced hub. Invite by email. Free to try.',
    heroTitle: 'Family Shared Notes App',
    heroSubtitle:
      'The Wi-Fi password, the school pickup schedule, the chore chart, the vacation packing list — every piece of household information, in shared notes the whole family can see and update from their own phones, the moment it changes. One household hub instead of a hundred scattered texts.',
    useCasesHeading: 'Run the household from one app',
    useCases: [
      {
        title: 'Household hub',
        description:
          'The information everyone asks for, finally in one findable place: Wi-Fi passwords, the plumber’s number, trash day, the garage code. Instead of texting Dad for the third time, anyone in the family opens the shared note and finds it in seconds.',
        icon: Home,
      },
      {
        title: 'Chores & tasks',
        description:
          'Weekly chore checklists the kids can actually check off, home project lists for the weekend warriors, holiday prep that doesn’t fall on one person. Everyone sees what’s done and what’s left — accountability without the nagging. The family meeting fits in a checklist now.',
        icon: CalendarCheck,
      },
      {
        title: 'Trip & event planning',
        description:
          'Packing lists the whole family adds to, the road-trip itinerary, the “don’t forget the sunscreen” notes. Plan the vacation together over weeks instead of in a panic the night before — and check the bags off as they go in the car.',
        icon: Plane,
      },
      {
        title: 'On every device',
        description:
          'Android phones, iPhones on the web app, the family laptop — InkSync keeps everyone in sync no matter what device each person carries. Grandma’s old tablet works too: if it runs a browser, it runs your family’s shared notes. Nobody needs new hardware to join in.',
        icon: Smartphone,
      },
      {
        title: 'School life, organized',
        description:
          'Pickup times, teacher names, practice schedules, permission-slip deadlines, the lunch menu. Give each kid’s school chaos its own shared note, and both parents — plus the babysitter — always know what’s happening this week. No more “I thought YOU were doing pickup.”',
        icon: CheckSquare,
      },
      {
        title: 'Emergency info, findable in seconds',
        description:
          'Doctor numbers, allergies, medications, insurance details, the neighbor with a spare key. The note nobody wants to need but everyone needs to find — shared with the whole household and readable offline, so it’s there even when the network isn’t.',
        icon: Bell,
      },
      {
        title: 'Grandparents stay in the loop',
        description:
          'Share the family calendar note, the kids’ recital dates, the “we’re visiting Sunday” plan. Grandparents don’t need to learn a new app — they open the web link on any device and see what’s happening, no group-chat archaeology required. Distance stops being an excuse for missing things.',
        icon: Heart,
      },
    ],
    stepsHeading: 'Get the household on the same page',
    steps: [
      {
        title: 'Create the notes your family actually needs',
        description:
          'Start with the highest-traffic lists: groceries, chores, school info, the vacation plan. One shared note per topic keeps things findable — the chore chart never gets buried under the packing list. Five minutes of setup saves a hundred “where is it?” texts.',
      },
      {
        title: 'Invite everyone by email',
        description:
          'Add each family member by email — partner, kids, grandparents, the regular babysitter. Everyone joins with their own InkSync account (free), on Android or through the web app. No shared logins, so everyone’s edits are their own. You’ll always know who added the ice cream.',
      },
      {
        title: 'Decide who sees what',
        description:
          'Not every note is for every person. Share the chore list with the kids, the budget note with just your partner, the vacation plan with the grandparents. You control the guest list for each note — the family hub stays organized instead of overwhelming.',
      },
      {
        title: 'Update once, everyone sees it',
        description:
          'Plans change — the dentist moves, practice is cancelled, dinner’s at seven now. Change the note once and the whole household sees it instantly. One source of truth beats eleven conflicting texts in the family group chat. Nobody shows up at the wrong time again.',
      },
      {
        title: 'Keep the grown-up stuff locked',
        description:
          'Budgets, medical details, the surprise birthday plan — lock sensitive notes with a password so they stay private even on a shared family tablet. The kids see their chore chart; they don’t see the mortgage spreadsheet. Privacy and sharing, on the same screen.',
      },
    ],
    faqs: [
      {
        question: 'How many family members can share notes?',
        answer:
          'As many as you like. Invite your partner, the kids, grandparents, and the regular babysitter by email — each person gets their own free account. There’s no per-note headcount limit getting in the way of a big family; everyone you invite sees and edits the same shared notes in real time.',
      },
      {
        question: 'Can I control who sees each note?',
        answer:
          'Yes. Sharing is per-note, not all-or-nothing: the chore chart goes to the kids, the budget note stays between the parents, the vacation plan includes the grandparents. You choose exactly who’s invited to each note, and you can remove someone anytime — the note disappears from their phone immediately. Total control, note by note.',
      },
      {
        question: 'Can my kids use InkSync?',
        answer:
          'Absolutely. Create a free account for each child and invite them only to the notes they need — chore checklists, packing lists, the family calendar. Their personal notes stay private to them, and they can’t see anything you haven’t explicitly shared. It’s a gentle first taste of being organized. And checking things off is weirdly fun for kids.',
      },
      {
        question: 'How do I keep some notes private from the family?',
        answer:
          'Two layers. First, nothing is shared unless you invite someone — your personal notes are invisible to the family by default. Second, for genuinely sensitive notes like finances or medical info, set a password lock on the note itself. Locked notes stay locked even on a shared family tablet. Privacy that survives the kids borrowing your phone.',
      },
      {
        question: 'What does the free plan include for a family?',
        answer:
          'Every family member gets a free account with up to 50 notes and checklists and real-time sync across their own devices — genuinely useful on its own. Sharing notes and collaborating in real time are Premium features: $0.99 per week or $33.99 per year, for unlimited notes, invites, Brain Dump, and AI proofread and tone rewrite.',
      },
      {
        question: 'Does it work offline?',
        answer:
          'Yes. InkSync saves everything on the device first, so the chore chart, the grocery list, and the emergency contacts all work with zero signal — in the basement, on a plane, at the cabin. Changes sync automatically when you’re back online, merging with anything the rest of the family added meanwhile.',
      },
      {
        question: 'What if someone deletes or messes up a shared note?',
        answer:
          'Only invited family members can edit a shared note, so nothing is exposed publicly. If a kid checks off the wrong chore or someone deletes an item by mistake, the real-time sync means you see it happen and can fix it on the spot — re-add the item, uncheck the box, done.',
      },
    ],
    ctaHeading: 'One app the whole family actually opens',
    ctaSubtext:
      'Set up your household hub today — free to try, no credit card required.',
    relatedLinks: [
      {
        label: 'Shared Grocery List App',
        url: '/shared-grocery-list-app/',
      },
      {
        label: 'Google Keep vs Apple Notes',
        url: '/compare/google-keep-vs-apple-notes/',
      },
    ],
  },
];
