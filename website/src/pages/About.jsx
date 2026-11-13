import { usePage, Cta, PageHero, SectionHead, Icon, COMPANY } from '../components/common.jsx';

const VALUES = [
  { icon: 'spark', tone: 'violet', title: 'Advice you can act on', text: 'A number alone does not help. Every Fit Score comes with a clear reason and specific things to add, swap or keep.' },
  { icon: 'hanger', tone: 'sage', title: 'Style what you own', text: 'Your wardrobe is the starting point. Savarun helps you get more out of the clothes already in your closet.' },
  { icon: 'shield', tone: 'deep', title: 'Safe by design', text: 'Chat only by request, report and block everywhere, a private wardrobe option and account deletion any time.' },
];

export default function About() {
  usePage(
    'About | Savarun AI Outfit Stylist',
    `About Savarun, an AI fashion and styling app by ${COMPANY}, India.`,
  );
  return (
    <>
      <PageHero crumb="About" eyebrow="About us" title={<>A personal stylist <span className="accent">in your pocket</span></>}>
        Savarun helps people understand their style, get more from their wardrobe and connect with others who love fashion.
      </PageHero>

      <section>
        <div className="container about-grid">
          <div className="about-art reveal">
            <img src="/site/street_4.webp" alt="Woman in a white shirt, black trousers and a leather jacket over her arm" width="600" height="800" loading="lazy" />
          </div>
          <div className="reveal">
            <span className="eyebrow">Our story</span>
            <h2 className="h2">Why we built Savarun</h2>
            <p className="lead">Getting dressed is a daily decision, yet honest, specific feedback on an outfit is hard to find. We built Savarun so anyone can snap a photo and get a clear, stylist-style read on their look: what works, what to change and how it fits current trends.</p>
            <p className="lead">Around that analyzer we added the things style lovers asked for: a digital wardrobe that tags itself, a community to share looks with, and a shop where approved brands can show their products.</p>
          </div>
        </div>
      </section>

      <section className="tinted">
        <div className="container">
          <SectionHead eyebrow="What we care about" title="Our principles" />
          <div className="values">
            {VALUES.map((v) => (
              <div className="feature reveal" key={v.title}>
                <div className={`ic ic-${v.tone}`}><Icon name={v.icon} /></div>
                <h3>{v.title}</h3>
                <p>{v.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section>
        <div className="container">
          <div className="company-card reveal">
            <div className="ic ic-violet"><Icon name="building" /></div>
            <div>
              <h3>Who runs Savarun</h3>
              <p>Savarun is built and operated by <b>{COMPANY}</b>, India. The app is for users aged 18 and over. Outfit analysis is powered by OpenAI's GPT-4o vision model.</p>
            </div>
          </div>
        </div>
      </section>

      <Cta />
    </>
  );
}
