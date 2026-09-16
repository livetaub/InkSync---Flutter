import { useParams, Navigate, Link } from 'react-router-dom';
import { ChevronRight, Check, X, Play } from 'lucide-react';
import { useDocumentMetadata } from '../hooks/useDocumentMetadata';
import { comparisonData } from '../data/comparisonData';
import './ComparisonPage.css';

export default function ComparisonPage() {
  const { slug } = useParams<{ slug: string }>();
  const data = comparisonData[slug || ''];

  // Hook must be called unconditionally
  useDocumentMetadata(
    data?.metaTitle || 'Compare Note Taking Apps | InkSync',
    data?.metaDescription || 'Compare top note-taking apps side by side.'
  );

  if (!data) {
    return <Navigate to="/" replace />;
  }

  const APP_URL = 'https://app.inksyncnote.com';
  const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.InkSync';

  // Data-driven FAQs: unique per page, built from the comparison data itself.
  // NOTE: the first answer uses verdictFaq (a short decision guide), NOT the
  // verdict verbatim — the Summary section already carries the full verdict.
  const faqs = [
    {
      question: `Which is better: ${data.competitorA.name} or ${data.competitorB.name}?`,
      answer: data.verdictFaq
    },
    {
      question: `What is the main difference between ${data.competitorA.name} and ${data.competitorB.name}?`,
      answer: `${data.competitorA.name}: ${data.competitorA.description} ${data.competitorB.name}: ${data.competitorB.description}`
    },
    {
      question: `Is there a good alternative to ${data.competitorA.name} and ${data.competitorB.name}?`,
      answer: `Yes. If neither ${data.competitorA.name} nor ${data.competitorB.name} ticks all your boxes, InkSync is a third option worth trying: ${data.whyInkSync[0].description} The free plan includes up to 50 notes with real-time sync across Android and Web.`
    },
    {
      question: `Can I try InkSync for free before switching?`,
      answer: `Absolutely. InkSync's free plan includes up to 50 notes and checklists with real-time sync across your devices — no credit card required. You can keep using ${data.competitorA.name} or ${data.competitorB.name} alongside it while you decide.`
    }
  ];

  const schemaData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        "headline": data.metaTitle,
        "description": data.metaDescription,
        "author": {
          "@type": "Organization",
          "name": "InkSync"
        }
      },
      {
        "@type": "FAQPage",
        "mainEntity": faqs.map((f) => ({
          "@type": "Question",
          "name": f.question,
          "acceptedAnswer": { "@type": "Answer", "text": f.answer }
        }))
      }
    ]
  };

  const otherComparisons = Object.keys(comparisonData)
    .filter(k => k !== slug)
    .slice(0, 3)
    .map(k => comparisonData[k]);

  // Cross-link: the dedicated alternative pages for each competitor.
  const ALT_SLUG_BY_NAME: Record<string, string> = {
    'Google Keep': 'google-keep-alternative',
    'Apple Notes': 'apple-notes-alternative',
    'Notion': 'notion-alternative',
    'Evernote': 'evernote-alternative',
    'Bear': 'bear-alternative',
    'Simplenote': 'simplenote-alternative',
  };
  const altLinks = [data.competitorA.name, data.competitorB.name]
    .map((n) => ALT_SLUG_BY_NAME[n] ? { name: n, slug: ALT_SLUG_BY_NAME[n] } : null)
    .filter((x): x is { name: string; slug: string } => x !== null);

  const renderFeatureValue = (value: string | boolean) => {
    if (value === true) return <Check className="icon-true" />;
    if (value === false) return <X className="icon-false" />;
    return <span>{value}</span>;
  };

  return (
    <div className="comparison-page-container">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schemaData) }} />
      
      <div className="comparison-content">
        {/* Breadcrumbs */}
        <nav className="breadcrumbs">
          <Link to="/">Home</Link>
          <ChevronRight size={16} />
          <span>Compare</span>
          <ChevronRight size={16} />
          <span className="current">{data.heroTitle}</span>
        </nav>

        {/* Hero Section */}
        <header className="comparison-hero">
          <div className="badge">Factual Comparison 2026</div>
          <h1>{data.heroTitle}</h1>
          <p className="subtitle">{data.heroSubtitle}</p>
        </header>

        {/* Quick Overview (Competitor A vs Competitor B Head-to-Head) */}
        <section className="overview-section">
          <div className="competitor-card">
            <h2>{data.competitorA.name}</h2>
            <p>{data.competitorA.description}</p>
            <div className="pros-cons">
              <div className="pros">
                <h3>Where {data.competitorA.name} Shines</h3>
                <ul>
                  {data.competitorA.strengths.map((s, i) => <li key={i}><Check size={16} className="text-green" /> {s}</li>)}
                </ul>
              </div>
              <div className="cons">
                <h3>Where {data.competitorA.name} Lags Behind</h3>
                <ul>
                  {data.competitorA.weaknesses.map((w, i) => <li key={i}><X size={16} className="text-red" /> {w}</li>)}
                </ul>
              </div>
            </div>
          </div>
          
          <div className="vs-badge">VS</div>

          <div className="competitor-card">
            <h2>{data.competitorB.name}</h2>
            <p>{data.competitorB.description}</p>
            <div className="pros-cons">
              <div className="pros">
                <h3>Where {data.competitorB.name} Shines</h3>
                <ul>
                  {data.competitorB.strengths.map((s, i) => <li key={i}><Check size={16} className="text-green" /> {s}</li>)}
                </ul>
              </div>
              <div className="cons">
                <h3>Where {data.competitorB.name} Lags Behind</h3>
                <ul>
                  {data.competitorB.weaknesses.map((w, i) => <li key={i}><X size={16} className="text-red" /> {w}</li>)}
                </ul>
              </div>
            </div>
          </div>
        </section>

        {/* Direct Feature Comparison Table (Only features at least one competitor has) */}
        <section className="table-section">
          <h2>{data.competitorA.name} vs {data.competitorB.name}: Feature Breakdown</h2>
          <div className="table-wrapper">
            <table className="comparison-table">
              <thead>
                <tr>
                  <th>Feature</th>
                  <th>{data.competitorA.name}</th>
                  <th>{data.competitorB.name}</th>
                </tr>
              </thead>
              <tbody>
                {data.features
                  .filter(row => row.competitorA !== false || row.competitorB !== false)
                  .map((row, idx) => (
                    <tr key={idx}>
                      <td className="feature-name">{row.feature}</td>
                      <td>{renderFeatureValue(row.competitorA)}</td>
                      <td>{renderFeatureValue(row.competitorB)}</td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </section>

        {/* Verdict between Competitor A and Competitor B */}
        <section className="verdict-section">
          <h2>Summary: {data.competitorA.name} vs {data.competitorB.name}</h2>
          <p>{data.verdict}</p>
        </section>

        {/* FAQ */}
        <section className="faq-section">
          <h2>{data.competitorA.name} vs {data.competitorB.name}: FAQs</h2>
          <div className="faq-list">
            {faqs.map((f, i) => (
              <div key={i} className="faq-item">
                <h3>{f.question}</h3>
                <p>{f.answer}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Section 2: Consider InkSync as Option 3 */}
        <section className="why-inksync-section">
          <div className="inksync-option-header">
            <span className="inksync-tag">Third Option</span>
            <h2>Looking for a 3rd Option? Consider InkSync</h2>
            <p className="inksync-intro">
              If neither {data.competitorA.name} nor {data.competitorB.name} ticks all your boxes, InkSync combines the core features of both while adding local-first offline support, a dedicated Brain Dump section, and AI proofreading.
            </p>
          </div>

          <div className="table-wrapper inksync-full-table">
            <table className="comparison-table">
              <thead>
                <tr>
                  <th>Feature</th>
                  <th>{data.competitorA.name}</th>
                  <th>{data.competitorB.name}</th>
                  <th className="inksync-col-header">InkSync</th>
                </tr>
              </thead>
              <tbody>
                {data.features.map((row, idx) => (
                  <tr key={idx}>
                    <td className="feature-name">{row.feature}</td>
                    <td>{renderFeatureValue(row.competitorA)}</td>
                    <td>{renderFeatureValue(row.competitorB)}</td>
                    <td className="inksync-col-cell">{renderFeatureValue(row.inksync)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="why-grid">
            {data.whyInkSync.map((point, idx) => (
              <div className="why-card" key={idx}>
                <h3>{point.title}</h3>
                <p>{point.description}</p>
              </div>
            ))}
          </div>

          <div className="cta-actions" style={{ marginTop: '32px' }}>
            <a href={APP_URL} className="btn btn-primary" target="_blank" rel="noopener noreferrer">
              Try InkSync Free (Up to 50 Notes)
            </a>
          </div>
        </section>

        {/* Related Comparisons */}
        <section className="related-section">
          <h3>Other Comparisons You Might Like</h3>
          <div className="related-links">
            {otherComparisons.map(comp => (
              <Link key={comp.slug} to={`/compare/${comp.slug}`} className="related-card">
                {comp.heroTitle}
              </Link>
            ))}
          </div>
        </section>

        {/* Cross-link: dedicated alternative pages */}
        {altLinks.length > 0 && (
          <section className="related-section">
            <h3>Looking for an alternative instead?</h3>
            <div className="related-links">
              {altLinks.map((a) => (
                <Link key={a.slug} to={`/alternative/${a.slug}/`} className="related-card">
                  Best {a.name} alternative in 2026
                </Link>
              ))}
            </div>
          </section>
        )}

        {/* Footer CTA */}
        <section className="footer-cta">
          <h2>Ready for a fast, local-first note app?</h2>
          <p>Try InkSync for free — works on Android and Web — iOS coming soon.</p>
          <div className="footer-buttons">
            <a href={APP_URL} className="btn btn-primary" target="_blank" rel="noopener noreferrer">
              Open Web App
            </a>
            <a href={PLAY_STORE_URL} className="btn btn-outline" target="_blank" rel="noopener noreferrer">
              <Play size={20} /> Get on Android
            </a>
          </div>
        </section>
      </div>
    </div>
  );
}

