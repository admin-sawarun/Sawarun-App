import { usePage, PageHero, SectionHead, Icon, Faq, EMAIL, StoreButtons } from '../components/common.jsx';
import { ShopVisual } from '../components/Visuals.jsx';

const STEPS = [
  { icon: 'phone', title: 'Apply in the app', text: 'Sign in to Savarun, open the Shop tab, tap "Sell", then "Apply with a Brand". Enter your brand name and website, and submit for review.' },
  { icon: 'shield', title: 'Our team reviews it', text: 'We check every brand before it goes live. You can see the status of your application (pending, approved or rejected) in the same screen.' },
  { icon: 'store', title: 'Your products go live', text: 'Once approved, your product cards (image, name, price, description and a link to your website) are added and, after a quick check, shown in the Shop tab. We guide you through it.' },
  { icon: 'link', title: 'Shoppers tap through', text: 'A tap on your product opens your own website, where the customer buys from you directly. Each tap is counted as an affiliate click.' },
];

export default function ForBrands() {
  usePage(
    'For Brands | Sell on Savarun',
    'Fashion brands can list products on Savarun. Apply in the app, get approved by our team, and shoppers tap through to buy on your own website. Free to apply.',
  );
  return (
    <>
      <PageHero crumb="For Brands" eyebrow="Sell on Savarun" title={<>Put your brand in front of <span className="accent">people who love style</span></>}>
        Savarun users come to rate their outfits and find what to add next. Get your products into the Shop tab, and send them straight to your website.
      </PageHero>

      <section>
        <div className="container">
          <SectionHead eyebrow="How listing works" title="Four steps from application to sales" />
          <div className="steps four">
            {STEPS.map((s, i) => (
              <div className="step reveal" key={s.title}>
                <div className="step-num">{i + 1}</div>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="tinted">
        <div className="container">
          <div className="showcase">
            <div className="show-visual reveal"><ShopVisual /></div>
            <div className="show-text reveal">
              <span className="eyebrow">Why Savarun</span>
              <h2>Built for fashion discovery</h2>
              <p>Your products sit inside an app people open to think about what they wear.</p>
              <ul className="checklist">
                <li><Icon name="check" />A dedicated Shop tab with category filters: Footwear, Tops, Accessories, Outerwear</li>
                <li><Icon name="check" />Trending Brands on the Home screen, and a Featured Brand slot chosen by our team</li>
                <li><Icon name="check" />Customers buy on your website, so you keep your checkout, pricing and customer relationship</li>
                <li><Icon name="check" />A trusted marketplace: only approved brands, and any listing can be paused</li>
              </ul>
              <div className="pill-note"><Icon name="gift" /><span><b>Free to apply</b> for now. There is no fee to submit your brand.</span></div>
            </div>
          </div>
        </div>
      </section>

      <section>
        <div className="container">
          <SectionHead eyebrow="Brand FAQ" title="Questions from brands" />
          <div className="faq-list">
            <Faq q="Who can apply?">Fashion brands with their own website where customers can buy. We review every application and may reject brands that don't fit the marketplace or our policies.</Faq>
            <Faq q="Does Savarun handle payments or delivery?">No. Savarun does not sell products. Shoppers tap your product and buy on your website, so payment, delivery, returns and customer service stay with you.</Faq>
            <Faq q="Can my products be removed?">Yes. Our team can hide any product, for example if a link is broken or a listing breaks our <a href="/terms">Terms</a>. Contact us and we'll help fix it.</Faq>
            <Faq q="I don't use the app. How do I get in touch?">Email <a href={`mailto:${EMAIL}`}>{EMAIL}</a> with your brand name and website, and we'll guide you through it.</Faq>
          </div>
        </div>
      </section>

      <section>
        <div className="container">
          <div className="cta-box reveal">
            <div>
              <h2>Ready to list your brand?</h2>
              <p>Apply from Shop → Sell in the app, or email us at <a className="on-dark" href={`mailto:${EMAIL}`}>{EMAIL}</a>.</p>
              <StoreButtons />
            </div>
            <div className="cta-logo"><img src="/site/logo_mark_white.png" alt="Savarun logo" width="61" height="80" /></div>
          </div>
        </div>
      </section>
    </>
  );
}
