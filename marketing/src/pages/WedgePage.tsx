import React from 'react';
import { Navigate, Link } from 'react-router-dom';
import { ChevronRight, ArrowRight, Share2 } from 'lucide-react';
import { useDocumentMetadata } from '../hooks/useDocumentMetadata';
import { wedgeData, SHARE_CTA } from '../data/wedgeData';
import './WedgePage.css';

interface WedgePageProps {
  slug: string;
}

const WedgePage: React.FC<WedgePageProps> = ({ slug }) => {
  const data = wedgeData.find((w) => w.slug === slug);

  if (!data) {
    return <Navigate to="/" replace />;
  }

  // Set SEO metadata
  useDocumentMetadata(data.metaTitle, data.metaDescription);

  // Generate JSON-LD FAQ Schema
  const faqSchema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: data.faqs.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.answer,
      },
    })),
  };

  const related = wedgeData.filter((w) => w.slug !== slug);

  return (
    <div className="wedge-page-container">
      <script type="application/ld+json">
        {JSON.stringify(faqSchema)}
      </script>

      <div className="wedge-content-wrapper">
        <div className="wedge-breadcrumb">
          <Link to="/">Home</Link>
          <ChevronRight size={16} />
          <span>{data.breadcrumb}</span>
        </div>

        <section className="wedge-hero">
          <h1>{data.heroTitle}</h1>
          <p>{data.heroSubtitle}</p>
          <a
            href={SHARE_CTA}
            className="wedge-hero-cta"
            data-track="wedge_hero_cta"
            data-cta={slug}
          >
            Try InkSync for Free <ArrowRight size={20} />
          </a>
        </section>

        <section className="wedge-section">
          <h2>{data.useCasesHeading}</h2>
          <div className="wedge-grid">
            {data.useCases.map((uc, idx) => {
              const IconComponent = uc.icon;
              return (
                <div key={idx} className="wedge-card">
                  <div className="wedge-card-icon">
                    <IconComponent size={24} />
                  </div>
                  <h3>{uc.title}</h3>
                  <p>{uc.description}</p>
                </div>
              );
            })}
          </div>
        </section>

        <section className="wedge-section">
          <h2>{data.stepsHeading}</h2>
          <div className="wedge-steps">
            {data.steps.map((step, idx) => (
              <div key={idx} className="wedge-step">
                <div className="wedge-step-number">{idx + 1}</div>
                <div>
                  <h3>{step.title}</h3>
                  <p>{step.description}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="wedge-section">
          <h2>Frequently asked questions</h2>
          <div className="wedge-faq">
            {data.faqs.map((faq, idx) => (
              <div key={idx} className="wedge-faq-item">
                <h3>{faq.question}</h3>
                <p>{faq.answer}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="wedge-cta-section">
          <Share2 size={32} />
          <h2>{data.ctaHeading}</h2>
          <p>{data.ctaSubtext}</p>
          <a
            href={SHARE_CTA}
            className="wedge-cta-btn"
            data-track="wedge_bottom_cta"
            data-cta={slug}
          >
            Get started free <ArrowRight size={20} />
          </a>
        </section>

        <section className="wedge-related">
          <h2>More ways to share with InkSync</h2>
          <div className="wedge-related-tags">
            {related.map((r) => (
              <Link key={r.slug} to={`/${r.slug}/`} className="wedge-related-tag">
                {r.breadcrumb}
              </Link>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
};

export default WedgePage;
