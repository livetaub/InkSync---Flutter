import { Check } from 'lucide-react';
import { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';
import './PricingPage.css';

interface PlanPricing {
  price_monthly: number;
  price_yearly: number;
  notes_limit: number;
  ai_credits_limit: number;
}

interface PricingConfig {
  [planId: string]: PlanPricing;
}

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
const supabase = supabaseUrl && supabaseAnonKey ? createClient(supabaseUrl, supabaseAnonKey) : null;

const PricingPage = () => {
  const APP_URL = 'https://app.inksyncnote.com';
  
  const [pricingConfig, setPricingConfig] = useState<PricingConfig>({
    free: { price_monthly: 0, price_yearly: 0, notes_limit: 75, ai_credits_limit: 0 },
    premium: { price_monthly: 4.99, price_yearly: 49.99, notes_limit: 250, ai_credits_limit: 100 },
    premium_pro: { price_monthly: 9.99, price_yearly: 99.99, notes_limit: 500, ai_credits_limit: 200 },
  });

  const [isAnnual, setIsAnnual] = useState(true);

  useEffect(() => {
    const fetchPricing = async () => {
      if (!supabase) return;
      try {
        const { data, error } = await supabase.from('global_pricing').select('*');
        if (data && !error) {
          const newConfig: PricingConfig = {
            free: { price_monthly: 0, price_yearly: 0, notes_limit: 75, ai_credits_limit: 0 },
            premium: { price_monthly: 4.99, price_yearly: 49.99, notes_limit: 250, ai_credits_limit: 100 },
            premium_pro: { price_monthly: 9.99, price_yearly: 99.99, notes_limit: 500, ai_credits_limit: 200 },
          };
          data.forEach((row: PlanPricing & { plan_id: string }) => {
            newConfig[row.plan_id] = row;
          });
          setPricingConfig(newConfig);
        }
      } catch {
        // Pricing fetch failed — fallback defaults are used
      }
    };
    fetchPricing();
  }, []);

  return (
    <div className="pricing-page">
      <div className="container">
        <div className="pricing-header animate-fade-up">
          <h1>Simple, transparent pricing</h1>
          <p>Start for free, upgrade when you need more power.</p>
          
          <div className="billing-toggle">
            <div className="toggle-bg">
              <button className={!isAnnual ? 'active' : ''} onClick={() => setIsAnnual(false)}>Monthly</button>
              <button className={isAnnual ? 'active' : ''} onClick={() => setIsAnnual(true)}>Annually</button>
            </div>
            {isAnnual && <span className="discount-badge">Save 20%</span>}
          </div>
        </div>

        <div className="pricing-grid animate-fade-up delay-200">
          {/* Free Plan */}
          <div className="pricing-card glass-panel">
            <div className="plan-name">free</div>
            <div className="plan-price">
              <span className="currency">$</span>
              <span className="amount">0</span>
              <span className="period">/forever</span>
            </div>
            
            <a href={`${APP_URL}/register`} className="btn-outline w-full">
              Get Started Free
            </a>

            <div className="plan-features">
              <Feature text={`Up to ${pricingConfig.free.notes_limit} notes/checklists`} />
              <Feature text="Sync across devices" />
              <Feature text="Organise notes with colors and tags" />
              <Feature text="Link notes to calendar" />
              <Feature text="Web, iOS & Android" />
            </div>
          </div>

          {/* Premium Plan */}
          <div className="pricing-card premium glass-panel">
            <div className="popular-badge">Most Popular</div>
            <div className="plan-name">Premium</div>
            <div className="plan-price">
              <span className="currency">$</span>
              <span className="amount">{isAnnual ? (pricingConfig.premium.price_yearly / 12).toFixed(2) : pricingConfig.premium.price_monthly}</span>
              <span className="period">/mo</span>
            </div>
            
            <a href={`${APP_URL}/register?plan=premium`} className="btn-primary w-full">
              Get Premium
            </a>

            <div className="plan-features">
              <div className="feature-item highlighted-feature">
                <Check size={20} color="var(--primary)" className="feature-check" />
                <strong>everything in free +</strong>
              </div>
              <Feature text={`${pricingConfig.premium.notes_limit} notes`} />
              <Feature text="Real-time collaboration with colleagues" />
              <Feature text="Lock notes for privacy" />
              <Feature text={`${pricingConfig.premium.ai_credits_limit} words of AI writing assistant`} />
            </div>
          </div>

          {/* Premium Pro Plan */}
          <div className="pricing-card glass-panel">
            <div className="plan-name">Premium pro</div>
            <div className="plan-price">
              <span className="currency">$</span>
              <span className="amount">{isAnnual ? (pricingConfig.premium_pro.price_yearly / 12).toFixed(2) : pricingConfig.premium_pro.price_monthly}</span>
              <span className="period">/mo</span>
            </div>
            
            <a href={`${APP_URL}/register?plan=premium_pro`} className="btn-outline w-full">
              Get Premium Pro
            </a>

            <div className="plan-features">
              <div className="feature-item highlighted-feature">
                <Check size={20} color="var(--primary)" className="feature-check" />
                <strong>everything on premium +</strong>
              </div>
              <Feature text={`${pricingConfig.premium_pro.notes_limit} notes`} />
              <Feature text={`${pricingConfig.premium_pro.ai_credits_limit} words of AI writing assistant`} />
              <Feature text="priority support" />
            </div>
          </div>
        </div>

        <div className="faq-section animate-fade-up delay-400">
          <h2>Frequently Asked Questions</h2>
          <div className="faq-grid">
            <div className="faq-item">
              <h4>Do I need a credit card for the free plan?</h4>
              <p>No, our free plan is completely free forever. You don't need a credit card to sign up.</p>
            </div>
            <div className="faq-item">
              <h4>How do upgrades work?</h4>
              <p>You can upgrade from inside the app at any time. We will securely process your payment via Stripe and immediately unlock your premium features.</p>
            </div>
            <div className="faq-item">
              <h4>Can I cancel anytime?</h4>
              <p>Yes! There are no long-term contracts. You can cancel your subscription at any time from your account settings.</p>
            </div>
            <div className="faq-item">
              <h4>Is my data secure?</h4>
              <p>Absolutely. We use industry-standard encryption to ensure your notes and private thoughts remain private.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const Feature = ({ text }: { text: string }) => (
  <div className="feature-item">
    <Check size={20} color="var(--primary)" className="feature-check" />
    <span>{text}</span>
  </div>
);

export default PricingPage;
