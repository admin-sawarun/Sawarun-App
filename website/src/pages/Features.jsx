import { Link } from 'react-router-dom';
import { usePage, Cta, PageHero, SectionHead, Icon } from '../components/common.jsx';
import { FactorBars, Phone, SCREENS } from '../components/Mockups.jsx';
import { WardrobeVisual, CommunityVisual, ShopVisual } from '../components/Visuals.jsx';

function Feature({ icon, tone, title, children }) {
  return (
    <div className="feature reveal">
      <div className={`ic ic-${tone}`}><Icon name={icon} /></div>
      <h3>{title}</h3>
      <p>{children}</p>
    </div>
  );
}

export default function Features() {
  usePage(
    'Features | Savarun AI Outfit Stylist',
    'Savarun features: AI Outfit Analyzer with Fit Score and Style DNA, a digital wardrobe with AI tagging, a style community with chat, and a shop of approved brands.',
  );
  return (
    <>
      <PageHero crumb="Features" eyebrow="Features" title={<>Four tools, <span className="accent">one style app</span></>}>
        Savarun brings together an AI outfit analyzer, a digital wardrobe, a style community and a shop of approved brands.
      </PageHero>

      <section id="analyzer">
        <div className="container">
          <div className="feature-split">
            <div className="reveal">
              <span className="eyebrow">Module 1</span>
              <h2 className="h2">AI Outfit Analyzer</h2>
              <p className="lead">The core of Savarun. Take a photo of your outfit and OpenAI's GPT-4o vision model reads it the way a stylist would: clothing type, colour palette, pattern, fabric, fit and accessories.</p>
            </div>
            <div className="show-visual compact reveal"><Phone screen={SCREENS.fitScore} /></div>
          </div>
          <div className="features-grid">
            <Feature icon="camera" tone="violet" title="Smart camera">Full-screen preview with a grid overlay to frame your look, flash on or off, front or back camera, or pick a photo from your gallery. Preview it, then retake or analyse.</Feature>
            <Feature icon="spark" tone="deep" title="Fit Score 0 to 100">Shown on an animated ring meter. Built from five weighted factors, so the number always has a reason behind it.</Feature>
            <Feature icon="layers" tone="sage" title="Style DNA">See your outfit broken into styles by percentage, for example Streetwear 70%, Minimalist 20%, Athleisure 10%.</Feature>
            <Feature icon="chart" tone="sand" title="Stylist report">A diagnosis, the current trend pulse, and clear advice on what to add, what to swap and what already works.</Feature>
            <Feature icon="grid" tone="violet" title="Suggestions & inspiration">"Suggestions for You" plus a grid of outfits other people shared in the same style, most popular first.</Feature>
            <Feature icon="history" tone="deep" title="Outfit history">Every analysis is saved, so you can open old reports and watch your scores improve.</Feature>
          </div>
          <div className="factor-box reveal">
            <h3>The five Fit Score factors</h3>
            <FactorBars />
          </div>
        </div>
      </section>

      <section id="wardrobe" className="tinted">
        <div className="container">
          <div className="feature-split reverse">
            <div className="reveal">
              <span className="eyebrow">Module 2</span>
              <h2 className="h2">Digital Wardrobe</h2>
              <p className="lead">Put your real closet in your pocket. Add clothes by photo, let the AI tag them, and build outfits from what you already own.</p>
            </div>
            <div className="show-visual compact reveal"><WardrobeVisual /></div>
          </div>
          <div className="features-grid">
            <Feature icon="camera" tone="violet" title="Add by photo or in bulk">Snap one item with the camera, or upload many at once from your phone gallery.</Feature>
            <Feature icon="tag" tone="deep" title="AI auto-tagging">Each item gets a category, its colour with an exact hex code, fabric, season and formality level.</Feature>
            <Feature icon="search" tone="sage" title="Folders, filters & search">Tops, Bottoms, Footwear, Accessories and Outerwear folders. Filter by colour, season or formality, or search any tag.</Feature>
            <Feature icon="layers" tone="sand" title="Outfit Sets">Pick items and save them as a named set, like "Office Monday Look", for quick access later.</Feature>
            <Feature icon="palette" tone="violet" title="Wardrobe insights">Total items, your most-used colours, and the least-worn pieces to help you declutter.</Feature>
            <Feature icon="spark" tone="deep" title="Gap alerts">Find out what your closet is missing, for example "You have 5 jeans but no formal trousers."</Feature>
          </div>
        </div>
      </section>

      <section id="community">
        <div className="container">
          <div className="feature-split">
            <div className="reveal">
              <span className="eyebrow">Module 3</span>
              <h2 className="h2">Style Community</h2>
              <p className="lead">Savarun is more than a personal tool. Share your looks, discover people with a style you love and talk one-on-one.</p>
            </div>
            <div className="show-visual compact reveal"><CommunityVisual /></div>
          </div>
          <div className="features-grid">
            <Feature icon="users" tone="violet" title="Your style profile">Profile photo, username and bio, your style preferences (Streetwear, Minimalist, Classic and more) and your past analysis scores.</Feature>
            <Feature icon="heart" tone="deep" title="Share & feed">Share outfits and see new posts from the people you follow in your home feed. Like the looks you love.</Feature>
            <Feature icon="search" tone="sage" title="Explore people">Search people by username or name, and filter by style to find Streetwear fans, Minimalists and more.</Feature>
            <Feature icon="user-plus" tone="sand" title="Follow">Follow anyone with one tap, unfollow just as easily. Follower and following counts are on every profile.</Feature>
            <Feature icon="chat" tone="violet" title="Chat by request">Send a chat request from someone's profile. Once they accept, chat 1-on-1 and share outfit images.</Feature>
            <Feature icon="shield" tone="deep" title="Report & block">Report or block any user, post or message. Keep your wardrobe public or private.</Feature>
          </div>
        </div>
      </section>

      <section id="shop" className="tinted">
        <div className="container">
          <SectionHead eyebrow="Module 4" title="Shop from approved brands">
            Discover products from fashion brands our team has reviewed, then buy on the brand's own website.
          </SectionHead>
          <div className="shop-wide reveal"><ShopVisual /></div>
          <div className="features-grid">
            <Feature icon="store" tone="violet" title="Approved brands only">Every brand is reviewed before its products appear. Our team can hide any product at any time.</Feature>
            <Feature icon="trend" tone="deep" title="Trending & featured">Trending brands and a featured brand on the Home screen, plus a dedicated Shop tab.</Feature>
            <Feature icon="link" tone="sage" title="Tap to buy">Product cards show the image, brand and price. Tap one to open the brand's website and complete your purchase there.</Feature>
          </div>
          <div className="center mt-40 reveal"><Link className="link-arrow" to="/for-brands">How brands get listed <Icon name="arrow" size={18} /></Link></div>
        </div>
      </section>

      <Cta />
    </>
  );
}
