import { Link } from 'react-router-dom';
import { usePage, Cta, StoreButtons, SectionHead, Faq, Icon } from '../components/common.jsx';
import { Phone, PhoneFan, SCREENS, FactorBars, FitRing, Bars, SAMPLE_DNA } from '../components/Mockups.jsx';
import { WardrobeVisual, CommunityVisual, ShopVisual, InspirationGrid } from '../components/Visuals.jsx';

function Showcase({ reverse, eyebrow, title, text, points, visual, link }) {
  return (
    <div className={`showcase${reverse ? ' reverse' : ''}`}>
      <div className="show-visual reveal">{visual}</div>
      <div className="show-text reveal">
        <span className="eyebrow">{eyebrow}</span>
        <h2>{title}</h2>
        <p>{text}</p>
        <ul className="checklist">
          {points.map((p) => <li key={p}><Icon name="check" />{p}</li>)}
        </ul>
        {link}
      </div>
    </div>
  );
}

export default function Home() {
  usePage(
    'Savarun | AI Outfit Stylist, Digital Wardrobe & Style Community',
    'Savarun rates your outfit with AI. Get a Fit Score from 0 to 100, your Style DNA and clear stylist advice, build a digital wardrobe, share your looks and shop from approved brands.',
  );
  return (
    <>
      <section className="hero">
        <div className="container hero-grid">
          <div className="hero-copy">
            <span className="eyebrow">Your AI fashion stylist</span>
            <h1>Snap your outfit. <span className="grad-text">Get your Fit Score.</span></h1>
            <p className="hero-lead">Savarun looks at your outfit photo and gives it a score from 0 to 100, breaks down your Style DNA and tells you what to add, swap or keep. Then organise your wardrobe, share your looks and shop from approved brands.</p>
            <StoreButtons />
            <div className="hero-points">
              <span><Icon name="check" />Free to use</span>
              <span><Icon name="check" />Report &amp; block built in</span>
              <span><Icon name="check" />Delete your account any time</span>
            </div>
          </div>
          <div className="hero-visual">
            <img className="hero-photo" src="/site/photo_outfit_selfie.webp" alt="Woman in a pink shirt taking a photo of her outfit in front of a clothes rack" width="840" height="1100" fetchPriority="high" />
            <Phone screen={SCREENS.fitScore} className="hero-phone" eager />
            <div className="float-card fc-1">
              <div className="ic ic-violet"><Icon name="spark" /></div>
              <div><b>Stylist report</b><small>Add, swap, keep</small></div>
            </div>
            <div className="float-card fc-2">
              <div className="ic ic-sage"><Icon name="hanger" /></div>
              <div><b>Auto-tagged</b><small>Colour, fabric, season</small></div>
            </div>
          </div>
        </div>
      </section>

      <section className="pillars-wrap">
        <div className="container">
          <div className="pillars reveal">
            <div className="pillar"><div className="ic"><Icon name="spark" /></div><div><b>AI Outfit Analyzer</b><small>Fit Score &amp; Style DNA</small></div></div>
            <div className="pillar"><div className="ic"><Icon name="hanger" /></div><div><b>Digital Wardrobe</b><small>Your closet, tagged by AI</small></div></div>
            <div className="pillar"><div className="ic"><Icon name="users" /></div><div><b>Style Community</b><small>Share, follow, chat</small></div></div>
            <div className="pillar"><div className="ic"><Icon name="bag" /></div><div><b>Shop</b><small>Products from approved brands</small></div></div>
          </div>
        </div>
      </section>

      <section className="score-section">
        <div className="container score-grid">
          <div className="reveal">
            <span className="eyebrow">How the Fit Score works</span>
            <h2 className="h2">One score, <span className="accent">five things a stylist checks</span></h2>
            <p className="lead">Your photo is analysed by OpenAI's GPT-4o vision model. It spots the clothing type, colours, pattern, fabric, fit and accessories, then rates the outfit on five weighted factors. Together they make your Fit Score from 0 to 100.</p>
            <div className="score-demo">
              <FitRing score={82} size={132} />
              <div>
                <b>Example: 82 / 100</b>
                <small>The score comes with a written report, so you know exactly why.</small>
              </div>
            </div>
          </div>
          <FactorBars />
        </div>
      </section>

      <section id="features">
        <div className="container">
          <SectionHead eyebrow="What you can do" title={<>Everything your style needs, <span className="accent">in one app</span></>}>
            Analyse a look, organise your closet, get inspired by other people and find pieces from brands you like.
          </SectionHead>

          <Showcase
            eyebrow="AI Outfit Analyzer"
            title="Know what's working, and what to change"
            text="Take a photo with the in-app camera (grid overlay, flash, front or back camera) or pick one from your gallery. In seconds you get a stylist-style report."
            points={[
              'Fit Score from 0 to 100 on an animated ring',
              'Diagnosis and trend pulse: how current the look is',
              'What to add, what to swap and what to keep',
              '"Suggestions for You" and an outfit inspiration grid',
              'Outfit history, so you can see your style improve',
            ]}
            visual={<PhoneFan screens={[SCREENS.styleDna, SCREENS.fitScore, SCREENS.styleReport]} />}
            link={<Link className="link-arrow" to="/features">Explore the analyzer <Icon name="arrow" size={18} /></Link>}
          />

          <Showcase
            reverse
            eyebrow="Digital Wardrobe"
            title="Your whole closet, organised by AI"
            text="Add clothes one at a time with your camera, or upload many at once from your gallery. AI tags each item for you."
            points={[
              'Auto-tags: category, colour (with hex code), fabric, season and formality',
              'Folders for Tops, Bottoms, Footwear, Accessories and Outerwear',
              'Filter and search by colour, season, formality or tag',
              'Save Outfit Sets like "Office Monday Look"',
              'Insights: colour breakdown, gap alerts and least-worn items',
            ]}
            visual={<WardrobeVisual />}
          />

          <Showcase
            eyebrow="Style Community"
            title="Share your looks and find your people"
            text="Set up a profile with your style preferences, post outfits and follow people whose style you like."
            points={[
              'A home feed of outfits from people you follow',
              'Explore and search people by username or style',
              '1-on-1 chat, only after your chat request is accepted',
              'Keep your wardrobe public or private',
              'Report or block any user, post or message',
            ]}
            visual={<CommunityVisual />}
          />

          <Showcase
            reverse
            eyebrow="Shop"
            title="Shop pieces from approved brands"
            text="Browse products from fashion brands our team has reviewed and approved. Tap a product to buy it on the brand's own website."
            points={[
              'Products from approved brands only',
              'Filter by category: Footwear, Tops, Accessories, Outerwear',
              'Checkout happens on the brand\'s website, not in the app',
            ]}
            visual={<ShopVisual />}
            link={<Link className="link-arrow" to="/for-brands">Are you a brand? Sell on Savarun <Icon name="arrow" size={18} /></Link>}
          />
        </div>
      </section>

      <section className="how">
        <div className="container">
          <SectionHead eyebrow="How it works" title={<>From photo to stylist advice in <span className="accent">3 steps</span></>} />
          <div className="steps">
            <div className="step reveal">
              <div className="step-media screen"><img src={SCREENS.home.src} alt={SCREENS.home.alt} width="600" height="1211" loading="lazy" /></div>
              <div className="step-num">1</div>
              <h3>Sign in</h3>
              <p>Download Savarun and log in with Google or your phone number and a one-time code. Add your style preferences to your profile.</p>
            </div>
            <div className="step reveal">
              <div className="step-media"><img src="/site/photo_mirror_selfie.webp" alt="Woman taking a mirror photo of her outfit" width="720" height="960" loading="lazy" /></div>
              <div className="step-num">2</div>
              <h3>Snap your outfit</h3>
              <p>Take a full-length photo with the in-app camera or choose one from your gallery, then tap analyse.</p>
            </div>
            <div className="step reveal">
              <div className="step-media screen"><img src={SCREENS.fitScore.src} alt={SCREENS.fitScore.alt} width="600" height="1211" loading="lazy" /></div>
              <div className="step-num">3</div>
              <h3>Get your report</h3>
              <p>See your Fit Score, Style DNA and what to add, swap or keep. Save it to your history or share it.</p>
            </div>
          </div>
          <div className="center mt-40 reveal"><Link className="btn btn-outline" to="/how-it-works">See the full walkthrough</Link></div>
        </div>
      </section>

      <section>
        <div className="container dna-grid">
          <div className="dna-card reveal">
            <div className="dna-card-head">
              <span>Style DNA</span>
              <small>Example breakdown</small>
            </div>
            <Bars items={SAMPLE_DNA} />
            <div className="dna-tags">
              <span>Oversized fit</span><span>Neutral palette</span><span>Sneakers</span>
            </div>
          </div>
          <div className="reveal">
            <span className="eyebrow">Style DNA</span>
            <h2 className="h2">See the styles <span className="accent">your look is made of</span></h2>
            <p className="lead">Most outfits mix more than one style. Savarun breaks every look down into percentages, like Streetwear 70%, Minimalist 20% and Athleisure 10%, so you can see your personal aesthetic and how it changes over time.</p>
            <ul className="checklist">
              <li><Icon name="check" />Styles such as Streetwear, Minimalist, Classic and Athleisure</li>
              <li><Icon name="check" />Inspiration from shared outfits in your dominant style</li>
              <li><Icon name="check" />Your past scores on your profile</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="tinted">
        <div className="container">
          <SectionHead eyebrow="Inspiration" title={<>Every style has <span className="accent">a story</span></>}>
            After each analysis, Savarun shows outfits the community shared in your dominant style, most popular first, so you always have a next idea to try.
          </SectionHead>
          <InspirationGrid />
        </div>
      </section>

      <section className="safety">
        <div className="container">
          <SectionHead eyebrow="Safety & privacy" title={<>Built to keep you <span className="accent">in control</span></>} />
          <div className="safety-grid">
            <div className="safe-item reveal"><div className="ic"><Icon name="flag" /></div><b>Report &amp; block</b><span>Report or block any user, post or message from inside the app. Our team reviews reports within 24 hours.</span></div>
            <div className="safe-item reveal"><div className="ic"><Icon name="eye-off" /></div><b>Private wardrobe</b><span>Your wardrobe can stay private. You choose what goes public.</span></div>
            <div className="safe-item reveal"><div className="ic"><Icon name="chat" /></div><b>Chat by request</b><span>Nobody can message you until you accept their chat request.</span></div>
            <div className="safe-item reveal"><div className="ic"><Icon name="trash" /></div><b>Delete any time</b><span>Delete your account from Settings, or from our <a href="/account-deletion">web page</a>.</span></div>
            <div className="safe-item reveal"><div className="ic"><Icon name="lock" /></div><b>Photos stay yours</b><span>Outfit photos are analysed through the OpenAI API. Under OpenAI's API policy, they are not used to train its models.</span></div>
          </div>
        </div>
      </section>

      <section>
        <div className="container">
          <SectionHead eyebrow="FAQ" title="Questions people ask first" />
          <div className="faq-list">
            <Faq q="Is Savarun free?">Yes. Savarun is free to download and use. There are no ads, and the app does not sell anything itself; when you buy from the Shop, you pay the brand on its own website.</Faq>
            <Faq q="How is the Fit Score calculated?">The AI rates your outfit on five factors: Trend Match (30%), Color Harmony (20%), Style Consistency (20%), Silhouette Balance (15%) and Accessories (15%). The weighted total is your Fit Score from 0 to 100.</Faq>
            <Faq q="What happens to my outfit photos?">Your photo is sent securely to the OpenAI API for analysis. Under OpenAI's API data policy, data sent through the API is not used to train its models. See our <a href="/privacy-policy">Privacy Policy</a> for details.</Faq>
            <Faq q="Who can use Savarun?">Savarun is for people aged 18 and over.</Faq>
          </div>
          <div className="center mt-40 reveal"><Link className="link-arrow" to="/faq">View all questions <Icon name="arrow" size={18} /></Link></div>
        </div>
      </section>

      <Cta />
    </>
  );
}
