// Section visuals built from real app screenshots and stock photos
// (Pexels, free licence). Photos show example outfits only.
import { Phone, SCREENS, GARMENTS, STREET } from './Mockups.jsx';
import { Icon } from './common.jsx';

/** Wardrobe screenshot with tagged garment photos around it. */
export function WardrobeVisual() {
  const [a, b, c] = GARMENTS;
  return (
    <div className="combo">
      <Phone screen={SCREENS.wardrobe} />
      <figure className="combo-tile t1"><img src={a.src} alt={a.alt} width="520" height="520" loading="lazy" /><figcaption>{a.tag}</figcaption></figure>
      <figure className="combo-tile t2"><img src={b.src} alt={b.alt} width="520" height="520" loading="lazy" /><figcaption>{b.tag}</figcaption></figure>
      <figure className="combo-tile t3"><img src={c.src} alt={c.alt} width="520" height="520" loading="lazy" /><figcaption>{c.tag}</figcaption></figure>
    </div>
  );
}

/** Profile screenshot with two outfit photos behind it. */
export function CommunityVisual() {
  return (
    <div className="combo">
      <img className="combo-photo p1" src={STREET[0].src} alt={STREET[0].alt} width="600" height="800" loading="lazy" />
      <img className="combo-photo p2" src={STREET[1].src} alt={STREET[1].alt} width="600" height="800" loading="lazy" />
      <Phone screen={SCREENS.profile} />
    </div>
  );
}

/** Product-style cards for the Shop section. */
export function ShopVisual() {
  const items = [
    { g: GARMENTS[3], cat: 'Accessories' },
    { g: GARMENTS[0], cat: 'Outerwear' },
    { g: GARMENTS[2], cat: 'Tops' },
    { g: GARMENTS[4], cat: 'Bottoms' },
  ];
  return (
    <div className="shop-grid">
      {items.map(({ g, cat }) => (
        <div className="shop-card" key={g.src}>
          <img src={g.src} alt={g.alt} width="520" height="520" loading="lazy" />
          <div className="shop-card-body">
            <small>{cat}</small>
            <span>Buy on site <Icon name="link" /></span>
          </div>
        </div>
      ))}
    </div>
  );
}

/** Grid of street-style outfit photos. */
export function InspirationGrid() {
  return (
    <div className="insp-grid">
      {STREET.map((p) => (
        <figure className="insp reveal" key={p.src}>
          <img src={p.src} alt={p.alt} width="600" height="800" loading="lazy" />
          <figcaption>{p.style}</figcaption>
        </figure>
      ))}
    </div>
  );
}
