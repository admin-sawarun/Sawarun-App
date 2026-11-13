// Device frames around real app screenshots, plus small data visuals
// (Fit Score ring, bars) used in explainer sections.
import { useId } from 'react';
import { FACTORS } from './common.jsx';

/** Real screenshots from the app, in public/site/. */
export const SCREENS = {
  home: { src: '/site/screen_home.webp', alt: 'Savarun home screen with the Analyze Outfit button and recent analyses' },
  fitScore: { src: '/site/screen_fit_score.webp', alt: 'Savarun Fit Score screen showing a score of 83 out of 100' },
  styleDna: { src: '/site/screen_style_dna.webp', alt: 'Savarun Style DNA screen: Streetwear 70%, Casual 20%, Vintage 10%' },
  styleReport: { src: '/site/screen_style_report.webp', alt: 'Savarun style report with diagnosis, trend pulse, what is working and prescription' },
  wardrobe: { src: '/site/screen_wardrobe.webp', alt: 'Savarun wardrobe screen with AI-tagged clothes and category filters' },
  profile: { src: '/site/screen_profile.webp', alt: 'Savarun profile screen with style tag, past scores and public wardrobe switch' },
};

/** A clean device frame with a real screenshot inside. */
export function Phone({ screen, className = '', eager = false }) {
  return (
    <div className={`phone ${className}`}>
      <div className="phone-screen">
        <img src={screen.src} alt={screen.alt} width="600" height="1211" loading={eager ? 'eager' : 'lazy'} />
      </div>
    </div>
  );
}

/** Three phones fanned out, the middle one in front. */
export function PhoneFan({ screens }) {
  return (
    <div className="phone-fan">
      <Phone screen={screens[0]} className="side left" />
      <Phone screen={screens[1]} className="front" />
      <Phone screen={screens[2]} className="side right" />
    </div>
  );
}

/** Rounded photo tile. */
export function Photo({ src, alt, className = '', w = 600, h = 800 }) {
  return <img className={`photo ${className}`} src={src} alt={alt} width={w} height={h} loading="lazy" />;
}

export const GARMENTS = [
  { src: '/site/garment_overshirt.webp', alt: 'Grey overshirt on a hanger', tag: 'Outerwear · Wool · Winter' },
  { src: '/site/garment_jeans.webp', alt: 'A stack of light-wash jeans', tag: 'Bottoms · Denim · All-season' },
  { src: '/site/garment_tee.webp', alt: 'Folded white t-shirt', tag: 'Tops · Cotton · Summer' },
  { src: '/site/garment_watch.webp', alt: 'Steel wristwatch', tag: 'Accessories · Steel' },
  { src: '/site/garment_denim.webp', alt: 'Folded indigo denim', tag: 'Bottoms · Denim' },
];

export const STREET = [
  { src: '/site/street_1.webp', alt: 'Man in a black oversized tee, olive trousers and bucket hat on city steps', style: 'Streetwear' },
  { src: '/site/street_4.webp', alt: 'Woman in a white shirt, black trousers and a leather jacket over her arm', style: 'Classic' },
  { src: '/site/street_2.webp', alt: 'Man in a printed short-sleeve shirt and dark trousers in the sun', style: 'Casual' },
  { src: '/site/street_3.webp', alt: 'Woman in a light printed jacket, black top and high-waisted jeans', style: 'Streetwear' },
  { src: '/site/street_5.webp', alt: 'Woman in a long denim vest, white shirt and jeans', style: 'Casual' },
  { src: '/site/street_6.webp', alt: 'Woman in a dark top and brown trousers on a shaded street', style: 'Minimalist' },
];

/** Fit Score ring meter. */
export function FitRing({ score = 82, size = 150, label = 'Fit Score' }) {
  const id = useId().replace(/:/g, '');
  const r = 42;
  const c = 2 * Math.PI * r;
  return (
    <div className="fit-ring" style={{ width: size, height: size }}>
      <svg viewBox="0 0 100 100" aria-hidden="true">
        <defs>
          <linearGradient id={`g${id}`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#3D3574" />
            <stop offset=".55" stopColor="#6C5CE7" />
            <stop offset="1" stopColor="#B9AEE8" />
          </linearGradient>
        </defs>
        <circle cx="50" cy="50" r={r} fill="none" strokeWidth="9" className="track" />
        <circle
          cx="50" cy="50" r={r} fill="none" stroke={`url(#g${id})`} strokeWidth="9" strokeLinecap="round"
          strokeDasharray={`${(c * score) / 100} ${c}`} transform="rotate(-90 50 50)"
        />
      </svg>
      <div className="fit-ring-label">
        <b>{score}</b>
        <small>{label}</small>
      </div>
    </div>
  );
}

/** Horizontal bars, used for Style DNA. */
export function Bars({ items, unit = '%' }) {
  return (
    <div className="bars">
      {items.map((it) => (
        <div className="bar-row" key={it.name}>
          <div className="bar-head"><span>{it.name}</span><b>{it.value}{unit}</b></div>
          <div className="bar-track"><i style={{ width: `${it.value}%` }} /></div>
        </div>
      ))}
    </div>
  );
}

export const SAMPLE_DNA = [
  { name: 'Streetwear', value: 70 },
  { name: 'Minimalist', value: 20 },
  { name: 'Athleisure', value: 10 },
];

/** The five weighted factors as bars (weights, not scores). */
export function FactorBars() {
  const colors = ['#3D3574', '#6C5CE7', '#8E80EC', '#B9AEE8', '#A9C4A0'];
  return (
    <div className="factors">
      {FACTORS.map((f, i) => (
        <div className="factor reveal" key={f.name}>
          <div className="factor-head">
            <b>{f.name}</b>
            <span className="factor-weight">{f.weight}%</span>
          </div>
          <div className="bar-track"><i style={{ width: `${(f.weight / 30) * 100}%`, background: colors[i] }} /></div>
          <p>{f.desc}</p>
        </div>
      ))}
    </div>
  );
}
