import { usePage, Cta, PageHero, SectionHead, Icon } from '../components/common.jsx';
import { Phone, SCREENS } from '../components/Mockups.jsx';

const STEPS = [
  {
    title: 'Download and sign in',
    text: 'Install Savarun and log in with your Google account or your phone number and a one-time code (Sign in with Apple is planned for iPhone).',
    list: ['Savarun is free to use', 'For people aged 18 and over', 'Set your profile photo, username, bio and style preferences'],
  },
  {
    title: 'Take a photo of your outfit',
    text: 'Open the camera from the Home screen. Use the grid overlay to fit your whole look in the frame, or pick a photo from your gallery.',
    list: ['Stand in good light, full length if you can', 'Turn the flash on or off, switch front or back camera', 'Preview the photo, then retake or continue'],
  },
  {
    title: 'Let the AI analyse it',
    text: 'Your photo is sent securely to OpenAI\'s GPT-4o vision model. It detects the clothing type, colour palette, pattern, fabric, fit and accessories.',
    list: ['Rated on Trend Match, Color Harmony, Style Consistency, Silhouette Balance and Accessories', 'Under OpenAI\'s API policy, your photo is not used to train its models'],
  },
  {
    title: 'Read your Fit Score and report',
    text: 'See your Fit Score from 0 to 100 on the ring meter, your Style DNA breakdown and a stylist report.',
    list: ['Diagnosis and trend pulse', 'What to add, what to swap, what to keep', '"Suggestions for You" and an outfit inspiration grid'],
  },
  {
    title: 'Build your wardrobe',
    text: 'Add the clothes you own, one by one or in bulk. AI tags each item, and you can combine them into named Outfit Sets.',
    list: ['Category, colour hex, fabric, season and formality tags', 'Insights: colour breakdown, gap alerts, least-worn items'],
  },
  {
    title: 'Share, connect and shop',
    text: 'Post your favourite looks, follow people whose style you like, chat after a request is accepted, and browse products from approved brands.',
    list: ['Report or block anyone, any time', 'Products open on the brand\'s own website'],
  },
];

const TIPS = [
  { icon: 'camera', title: 'Full-length photo', text: 'Include shoes and accessories: they count toward your score.' },
  { icon: 'spark', title: 'Good light', text: 'Daylight or a bright room helps the AI read colours correctly.' },
  { icon: 'layers', title: 'Plain background', text: 'A simple background keeps the focus on your outfit.' },
  { icon: 'history', title: 'Try again', text: 'Make a swap the report suggests, then re-analyse to compare.' },
];

export default function HowItWorks() {
  usePage(
    'How It Works | Savarun AI Outfit Stylist',
    'How Savarun works: sign in, photograph your outfit, get a Fit Score, Style DNA and stylist report from AI, then build your wardrobe, share looks and shop.',
  );
  return (
    <>
      <PageHero crumb="How it works" eyebrow="How it works" title={<>From photo to <span className="accent">stylist advice</span></>}>
        Here's what happens from the moment you open Savarun.
      </PageHero>

      <section className="flow-section">
        <div className="container">
          <div className="flow reveal">
            <figure className="flow-item">
              <div className="flow-photo"><img src="/site/photo_ring_light.webp" alt="Woman checking her outfit in front of a ring light and mirror" width="900" height="640" loading="lazy" /></div>
              <figcaption><b>1. Snap</b>Take a photo of your outfit</figcaption>
            </figure>
            <span className="flow-arrow" aria-hidden="true"><Icon name="arrow" /></span>
            <figure className="flow-item">
              <Phone screen={SCREENS.fitScore} />
              <figcaption><b>2. Score</b>Get your Fit Score</figcaption>
            </figure>
            <span className="flow-arrow" aria-hidden="true"><Icon name="arrow" /></span>
            <figure className="flow-item">
              <Phone screen={SCREENS.styleReport} />
              <figcaption><b>3. Improve</b>Read your style report</figcaption>
            </figure>
          </div>
        </div>
      </section>

      <section style={{ paddingTop: 0 }}>
        <div className="container">
          <div className="guide">
            {STEPS.map((s, i) => (
              <div className="guide-item reveal" key={s.title}>
                <div className="step-num">{i + 1}</div>
                <div>
                  <h3>{s.title}</h3>
                  <p>{s.text}</p>
                  <ul>{s.list.map((l) => <li key={l}>{l}</li>)}</ul>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="tinted">
        <div className="container">
          <SectionHead eyebrow="Tips" title="Get the most accurate score" />
          <div className="tips">
            {TIPS.map((t) => (
              <div className="tip reveal" key={t.title}>
                <div className="ic ic-violet"><Icon name={t.icon} /></div>
                <b>{t.title}</b>
                <span>{t.text}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      <Cta />
    </>
  );
}
