import React from 'react';
import { useParams, Navigate, Link } from 'react-router-dom';
import { ChevronRight, ArrowRight, Check, X } from 'lucide-react';
import { useDocumentMetadata } from '../hooks/useDocumentMetadata';
import { alternativesData } from '../data/alternativeData';
import { comparisonData } from '../data/comparisonData';
import './AlternativePage.css';

const APP_URL = 'https://app.inksyncnote.com';

const AlternativePage: React.FC = () => {
  const { slug } = useParams<{ slug: string }>();
  const data = alternativesData.find((alt) => alt.slug === slug);

  if (!data) {
    return <Navigate to="/" replace />;
  }

  // Cross-link: head-to-head comparisons involving this competitor.
  const competitorKey = data.slug.replace(/-alternative$/, '');
  const relatedComparisons = Object.keys(comparisonData)
    .filter((k) => k.includes(competitorKey))
    .map((k) => comparisonData[k]);

  // Set SEO metadata
  useDocumentMetadata(data.metaTitle, data.metaDescription);

  // Generate JSON-LD Schema
  const schemaOrg = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Article',
        headline: data.metaTitle,
        description: data.metaDescription,
        author: {
          '@type': 'Organization',
          name: 'InkSync'
        },
        publisher: {
          '@type': 'Organization',
          name: 'InkSync'
        }
      },
      {
        '@type': 'FAQPage',
        mainEntity: data.faqs.map((faq) => ({
          '@type': 'Question',
          name: faq.question,
          acceptedAnswer: {
            '@type': 'Answer',
            text: faq.answer,
          },
        })),
      },
    ]
  };

  return (
    <div className="alternative-page-container">
      <script type="application/ld+json">
        {JSON.stringify(schemaOrg)}
      </script>

      <div className="alt-content-wrapper">
        <div className="alt-breadcrumb">
          <Link to="/">Home</Link>
          <ChevronRight size={16} />
          <span>Alternatives</span>
          <ChevronRight size={16} />
          <span>{data.competitorName}</span>
        </div>

        <section className="alt-hero">
          <h1>{data.heroTitle}</h1>
          <p>{data.heroSubtitle}</p>
          <a href={APP_URL} className="alt-hero-cta">
            Try InkSync for Free <ArrowRight size={20} />
          </a>
        </section>

        <section className="alt-section">
          <h2>Common reasons users explore a {data.competitorName} alternative</h2>
          <div className="alt-grid">
            {data.painPoints.map((pain, idx) => {
              const IconComponent = pain.icon;
              return (
                <div key={idx} className="alt-card pain-card">
                  <div className="alt-card-icon">
                    <IconComponent size={24} />
                  </div>
                  <h3>{pain.title}</h3>
                  <p>{pain.description}</p>
                </div>
              );
            })}
          </div>
        </section>

        <section className="alt-section">
          <h2>What InkSync offers instead</h2>
          <div className="alt-grid">
            {data.solutions.map((solution, idx) => {
              const IconComponent = solution.icon;
              return (
                <div key={idx} className="alt-card solution-card">
                  <div className="alt-card-icon">
                    <IconComponent size={24} />
                  </div>
                  <h3>{solution.title}</h3>
                  <p>{solution.description}</p>
                </div>
              );
            })}
          </div>
        </section>

        <section className="alt-section">
          <h2>InkSync vs {data.competitorName}</h2>
          <div style={{ overflowX: 'auto' }}>
            <table className="alt-comparison-table">
              <thead>
                <tr>
                  <th>Feature</th>
                  <th>{data.competitorName}</th>
                  <th className="th-inksync">InkSync</th>
                </tr>
              </thead>
              <tbody>
                {data.features.map((feature, idx) => (
                  <tr key={idx}>
                    <td>{feature.feature}</td>
                    <td>
                      {typeof feature.competitor === 'boolean' ? (
                        feature.competitor ? <Check size={20} className="check-icon" /> : <X size={20} className="x-icon" />
                      ) : (
                        feature.competitor
                      )}
                    </td>
                    <td className="td-inksync">
                      {typeof feature.inksync === 'boolean' ? (
                        feature.inksync ? <Check size={20} className="check-icon" /> : <X size={20} className="x-icon" />
                      ) : (
                        feature.inksync
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="alt-cta-section">
          <blockquote>"{data.switchQuote}"</blockquote>
          <a href={APP_URL} className="alt-cta-btn">
            Make the switch today <ArrowRight size={20} />
          </a>
        </section>

        <section className="alt-section">
          <h2>How to switch from {data.competitorName} to InkSync</h2>
          <div className="alt-steps">
            {data.switchSteps.map((step, idx) => (
              <div key={idx} className="alt-step">
                <div className="alt-step-number">{idx + 1}</div>
                <div>
                  <h3>{step.title}</h3>
                  <p>{step.description}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="alt-section">
          <h2>{data.competitorName} alternative: FAQs</h2>
          <div className="alt-faq">
            {data.faqs.map((faq, idx) => (
              <div key={idx} className="alt-faq-item">
                <h3>{faq.question}</h3>
                <p>{faq.answer}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="related-alts">
          <h2>Compare InkSync with other apps</h2>
          <div className="related-tags">
            {alternativesData
              .filter(alt => alt.slug !== slug)
              .map(alt => (
                <Link key={alt.slug} to={`/alternative/${alt.slug}`} className="related-tag">
                  vs {alt.competitorName}
                </Link>
              ))}
          </div>
        </section>

        {relatedComparisons.length > 0 && (
          <section className="related-alts">
            <h2>{data.competitorName} head-to-head comparisons</h2>
            <div className="related-tags">
              {relatedComparisons.map((comp) => (
                <Link key={comp.slug} to={`/compare/${comp.slug}/`} className="related-tag">
                  {comp.heroTitle}
                </Link>
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
};

export default AlternativePage;
