import React from 'react';
import './TermsPage.css';

const TermsPage: React.FC = () => {
  return (
    <div className="terms-page">
      <div className="terms-container animate-fade-up">
        <header className="terms-header">
          <h1>Terms of Service & Privacy Policy</h1>
          <p className="last-updated">Last Updated: May 25, 2026</p>
        </header>

        <div className="terms-content">
          <section className="intro-section">
            <p>
              Welcome to <strong>InkSync</strong> (accessible via our web application at app.inksyncnote.com, our mobile application, and our landing site). 
              Please read these Terms of Service ("Terms") and our Privacy Policy carefully before using our services. By accessing or using InkSync, 
              you agree to be bound by these Terms and our Privacy Policy. If you do not agree to all of the terms, do not access or use the services.
            </p>
          </section>

          <hr className="divider" />

          {/* ==================== PART 1: TERMS OF SERVICE ==================== */}
          <h2>Part 1: Terms of Service</h2>

          <section>
            <h3>1. Disclaimer of Note Privacy & Security</h3>
            <p className="highlight-text">
              <strong>IMPORTANT NOTICE:</strong> While we implement standard security protocols (including encryption of data in transit and at rest), 
              we do not guarantee absolute security or privacy. 
            </p>
            <p>
              You acknowledge and agree that:
            </p>
            <ul>
              <li><strong>No Liability for Data Loss:</strong> We do not take responsibility for any unauthorized access to, alteration of, or deletion of your notes or account data.</li>
              <li><strong>Your Security Responsibilities:</strong> You are solely responsible for protecting your account credentials and passwords. If you utilize the local note-locking feature, you must securely remember your password; we cannot retrieve locked notes if you lose your password.</li>
              <li><strong>Local Storage & Syncing:</strong> If you use the guest mode (without an account), notes are saved only on your local device's browser cache/storage. Clearing your cache or uninstalling the app will permanently delete these notes. We are not liable for data lost in this manner.</li>
            </ul>
          </section>

          <section>
            <h3>2. Discontinuation of Support & Service Changes</h3>
            <p>
              We reserve the right to modify, suspend, or terminate the app, any feature, or the entire service at any time, for any reason, and **with no prior warning**. 
              We shall not be liable to you or any third party for any modification, suspension, or discontinuation of the service.
            </p>
          </section>

          <section>
            <h3>3. Subscription Pricing & Tier Modification</h3>
            <p>
              We reserve the right to adjust subscription pricing, features, limits, or benefits associated with subscription tiers (Free, Premium, Premium Pro) at our sole discretion:
            </p>
            <ul>
              <li>Pricing adjustments will take effect at the start of the next billing cycle after the change is made.</li>
              <li>Continued use of the services after a pricing change constitutes agreement to the new pricing.</li>
              <li>If you do not wish to accept the price adjustment, you must cancel your subscription prior to the end of the current billing cycle.</li>
            </ul>
          </section>

          <section>
            <h3>4. Modification of Terms</h3>
            <p>
              We reserve the right, at our sole discretion, to update, change, or replace any part of these Terms by posting updates and changes to our website. 
              It is your responsibility to check our website periodically for changes. Your continued use of or access to our services following the posting of 
              any changes to these Terms constitutes acceptance of those changes.
            </p>
          </section>

          <section>
            <h3>5. Acceptable Use</h3>
            <p>
              You agree not to use the services for any unlawful purpose, to transmit malicious code, to attempt unauthorized access to our servers or databases, 
              or to engage in any behavior that degrades the service for other users. Violation of this section may result in immediate suspension or termination of your account.
            </p>
          </section>

          <section>
            <h3>6. Limitation of Liability</h3>
            <p>
              To the maximum extent permitted by applicable law, in no event shall InkSync, its owners, developers, or affiliates be liable for any indirect, 
              incidental, special, consequential, or punitive damages, including loss of profits, data, use, goodwill, or other intangible losses, resulting from:
            </p>
            <ul>
              <li>Your access to or use of, or inability to access or use, the services;</li>
              <li>Any conduct or content of any third party on the services;</li>
              <li>Any content obtained from the services; and</li>
              <li>Unauthorized access, use, or alteration of your transmissions or content.</li>
            </ul>
            <p>
              In no event shall our total aggregate liability exceed the amount paid by you to us for the services in the twelve (12) months preceding the event giving rise to liability, or ten dollars ($10.00 USD), whichever is greater.
            </p>
          </section>

          <hr className="divider" />

          {/* ==================== PART 2: PRIVACY POLICY ==================== */}
          <h2>Part 2: Privacy Policy</h2>

          <section>
            <h3>1. Information We Collect</h3>
            <p>
              To provide InkSync notes, sync, and collaboration features, we collect and store:
            </p>
            <ul>
              <li><strong>Account Information:</strong> Your email address and authentication metadata when creating an account or logging in via Google.</li>
              <li><strong>Notes Content & Metadata:</strong> The text, tags, accent colors, calendar associations, and pinned states of notes created while logged in, so we can sync them to our database.</li>
              <li><strong>Payment Information:</strong> We do not store credit card details on our servers. All payments are processed securely by Stripe. We only store customer IDs, subscription status, and billing cycle dates generated by Stripe.</li>
              <li><strong>Usage Analytics:</strong> Basic anonymous logging to diagnose server performance and optimize app load times.</li>
            </ul>
          </section>

          <section>
            <h3>2. How We Use Your Information</h3>
            <p>
              We use the collected information solely to:
            </p>
            <ul>
              <li>Deliver, synchronize, and support the InkSync application.</li>
              <li>Verify your identity and manage subscriptions.</li>
              <li>Enable collaboration features when you invite others to view/edit your notes.</li>
              <li>Ensure server security and fix bugs.</li>
            </ul>
          </section>

          <section>
            <h3>3. Data Retention & Deletion</h3>
            <p>
              If you delete your notes, they are permanently removed from our active databases (and deleted from backup copies after a standard cycle). 
              If you wish to delete your account entirely, you can request account deletion by emailing us at <a href="mailto:support@inksyncnote.com" className="email-link">support@inksyncnote.com</a>.
            </p>
          </section>

          <section className="contact-footer">
            <h3>Questions & Contact</h3>
            <p>
              If you have any questions about these Terms of Service or our Privacy Policy, please contact us at:
            </p>
            <p className="contact-email">
              <a href="mailto:support@inksyncnote.com">support@inksyncnote.com</a>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
};

export default TermsPage;
