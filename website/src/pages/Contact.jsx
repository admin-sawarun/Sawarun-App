import { Link } from 'react-router-dom';
import { usePage, PageHero, Icon, EMAIL, COMPANY, Cta, PLAY_LIVE } from '../components/common.jsx';

export default function Contact() {
  usePage(
    'Contact | Savarun AI Outfit Stylist',
    `Contact the Savarun team at ${EMAIL} for support, brand listings, safety reports or feedback.`,
  );
  return (
    <>
      <PageHero crumb="Contact" eyebrow="Contact" title={<>We'd love to <span className="accent">hear from you</span></>}>
        Questions, feedback, brand enquiries or safety concerns: one email reaches our team.
      </PageHero>

      <section>
        <div className="container">
          <div className="contact-grid">
            <div className="contact-card reveal">
              <div className="ic ic-violet"><Icon name="mail" /></div>
              <h3>Support &amp; feedback</h3>
              <p>Help with your account, the analyzer or your wardrobe, or ideas for the app.</p>
              <a href={`mailto:${EMAIL}`}>{EMAIL}</a>
            </div>
            <div className="contact-card reveal">
              <div className="ic ic-sage"><Icon name="store" /></div>
              <h3>Brands</h3>
              <p>Want your products in the Savarun Shop? Apply in the app or email us with your brand name and website.</p>
              <Link to="/for-brands">Sell on Savarun</Link>
            </div>
            <div className="contact-card reveal">
              <div className="ic ic-deep"><Icon name="flag" /></div>
              <h3>Safety reports</h3>
              <p>Report content from inside the app. For anything urgent, especially involving a minor, email us right away.</p>
              <a href="/child-safety">Child Safety Standards</a>
            </div>
          </div>

          {!PLAY_LIVE && (
          <div className="contact-extra reveal">
            <div>
              <h3>Want to know when Savarun launches?</h3>
              <p>Savarun is coming soon to Google Play and the App Store. Email us and we'll let you know when it's live.</p>
            </div>
            <a className="btn btn-primary" href={`mailto:${EMAIL}?subject=Savarun%20launch`}>Email us</a>
          </div>
          )}

          <div className="company-card reveal">
            <div className="ic ic-violet"><Icon name="building" /></div>
            <div>
              <h3>{COMPANY}</h3>
              <p>India · <a href={`mailto:${EMAIL}`}>{EMAIL}</a></p>
              <p className="small-links"><a href="/privacy-policy">Privacy Policy</a> · <a href="/terms">Terms</a> · <a href="/account-deletion">Delete Account</a></p>
            </div>
          </div>
        </div>
      </section>
      <Cta />
    </>
  );
}
