import { useEffect } from 'react';
import { Link } from 'react-router-dom';

/** Google Play listing. The app is not published yet. */
export const PLAY_URL = 'https://play.google.com/store/apps/details?id=com.savarun.savarun';
/** Set to true once the app is live on Google Play: the Play badge then links to PLAY_URL. */
export const PLAY_LIVE = false;
export const EMAIL = 'admin-sawarun@savarun.in';
export const COMPANY = 'SAWARUN TECH PRIVATE LIMITED';

/** The five Fit Score factors and their default weights. */
export const FACTORS = [
  { name: 'Trend Match', weight: 30, desc: 'How current the look is against what is trending right now.' },
  { name: 'Color Harmony', weight: 20, desc: 'How well the colours in the outfit work together.' },
  { name: 'Style Consistency', weight: 20, desc: 'Whether the pieces belong to the same style story.' },
  { name: 'Silhouette Balance', weight: 15, desc: 'Proportions and fit: slim, oversized, loose, layered.' },
  { name: 'Accessories', weight: 15, desc: 'Caps, chains, bags, shoes and how they finish the look.' },
];

/** Sets the browser tab title and meta description for the current page. */
export function usePage(title, description) {
  useEffect(() => {
    document.title = title;
    const meta = document.querySelector('meta[name="description"]');
    if (meta && description) meta.setAttribute('content', description);
  }, [title, description]);
}

export function Icon({ name, className, size }) {
  return (
    <svg className={className} width={size} height={size} aria-hidden="true"><use href={`#i-${name}`} /></svg>
  );
}

export function StoreButtons() {
  return (
    <div className="store-buttons">
      {PLAY_LIVE ? (
        <a className="btn btn-store" href={PLAY_URL} target="_blank" rel="noopener">
          <Icon name="play" />
          <div><small>GET IT ON</small><span>Google Play</span></div>
        </a>
      ) : (
        <span className="btn btn-store disabled" title="Coming soon">
          <Icon name="play" />
          <div><small>COMING SOON ON</small><span>Google Play</span></div>
        </span>
      )}
      <span className="btn btn-store disabled" title="Coming soon">
        <Icon name="apple" />
        <div><small>COMING SOON ON THE</small><span>App Store</span></div>
      </span>
    </div>
  );
}

export function PageHero({ crumb, eyebrow, title, children }) {
  return (
    <section className="page-hero">
      <div className="container">
        <div className="crumbs"><Link to="/">Home</Link> / {crumb}</div>
        <span className="eyebrow">{eyebrow}</span>
        <h1>{title}</h1>
        {children && <p>{children}</p>}
      </div>
    </section>
  );
}

export function SectionHead({ eyebrow, title, children }) {
  return (
    <div className="section-head reveal">
      {eyebrow && <span className="eyebrow">{eyebrow}</span>}
      <h2>{title}</h2>
      {children && <p>{children}</p>}
    </div>
  );
}

export function Faq({ q, children }) {
  return (
    <details className="reveal">
      <summary>{q}<span className="pm"><Icon name="plus" /></span></summary>
      <div className="answer">{children}</div>
    </details>
  );
}

export function Cta({ title = 'Find out what your outfit scores', text = 'Snap a look, get your Fit Score and Style DNA, and build a wardrobe that works for you. Savarun is free to use.' }) {
  return (
    <section>
      <div className="container">
        <div className="cta-box reveal">
          <div>
            <h2>{title}</h2>
            <p>{text}</p>
            <StoreButtons />
          </div>
          <div className="cta-logo"><img src="/site/logo_mark_white.png" alt="Savarun logo" width="61" height="80" /></div>
        </div>
      </div>
    </section>
  );
}
