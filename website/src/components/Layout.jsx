import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import iconSprite from './icons.svg.html?raw';
import { PLAY_URL, PLAY_LIVE, EMAIL, COMPANY } from './common.jsx';

const NAV = [
  { to: '/features', label: 'Features' },
  { to: '/how-it-works', label: 'How it works' },
  { to: '/for-brands', label: 'For Brands' },
  { to: '/faq', label: 'FAQ' },
  { to: '/about', label: 'About' },
  { to: '/contact', label: 'Contact' },
];

function Brand({ white }) {
  return (
    <>
      <span className="brand-mark"><img src={white ? '/site/logo_mark_white.png' : '/site/logo_mark.png'} alt="" width="21" height="28" /></span>
      <div><b>Savarun</b><small>AI Outfit Stylist</small></div>
    </>
  );
}

function Header() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const { pathname } = useLocation();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  // Close the mobile menu after navigating.
  useEffect(() => setOpen(false), [pathname]);

  return (
    <header className={scrolled || open ? 'scrolled' : ''}>
      <div className="container nav">
        <Link className="brand" to="/" aria-label="Savarun home"><Brand /></Link>
        <button className="menu-btn" aria-label={open ? 'Close menu' : 'Open menu'} aria-expanded={open} aria-controls="nav-links" onClick={() => setOpen((o) => !o)}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            {open ? <path d="M6 6l12 12M18 6L6 18" /> : <path d="M4 7h16M4 12h16M4 17h16" />}
          </svg>
        </button>
        <nav className={`nav-links${open ? ' open' : ''}`} id="nav-links">
          {NAV.map((n) => <NavLink key={n.to} to={n.to}>{n.label}</NavLink>)}
          {PLAY_LIVE
            ? <a className="btn btn-primary" href={PLAY_URL} target="_blank" rel="noopener">Get the app</a>
            : <Link className="btn btn-primary" to="/contact">Get early access</Link>}
        </nav>
      </div>
    </header>
  );
}

function Footer() {
  return (
    <footer>
      <div className="container">
        <div className="footer-grid">
          <div>
            <Link className="brand" to="/"><Brand white /></Link>
            <p>Rate your outfit with AI, build a digital wardrobe and share your style. Made in India by {COMPANY}.</p>
          </div>
          <div>
            <h4>App</h4>
            <ul>
              <li><Link to="/features">Features</Link></li>
              <li><Link to="/how-it-works">How it works</Link></li>
              <li><Link to="/for-brands">For Brands</Link></li>
              <li><Link to="/faq">FAQ</Link></li>
            </ul>
          </div>
          <div>
            <h4>Legal</h4>
            <ul>
              {/* Served by the backend as plain pages, not part of this React site. */}
              <li><a href="/privacy-policy">Privacy Policy</a></li>
              <li><a href="/terms">Terms &amp; Conditions</a></li>
              <li><a href="/account-deletion">Delete Account</a></li>
              <li><a href="/child-safety">Child Safety</a></li>
            </ul>
          </div>
          <div>
            <h4>Company</h4>
            <ul>
              <li><Link to="/about">About</Link></li>
              <li><Link to="/contact">Contact</Link></li>
              <li><a href={`mailto:${EMAIL}`}>{EMAIL}</a></li>
              {PLAY_LIVE && <li><a href={PLAY_URL} target="_blank" rel="noopener">Google Play</a></li>}
            </ul>
          </div>
        </div>
        <div className="footer-bottom">
          <span>&copy; {new Date().getFullYear()} {COMPANY}. All rights reserved.</span>
          <span>Made in India 🇮🇳</span>
        </div>
      </div>
    </footer>
  );
}

/** Scroll to top on page change and fade in `.reveal` blocks as they scroll into view. */
function usePageEffects() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
    const items = document.querySelectorAll('.reveal:not(.in)');
    if (!('IntersectionObserver' in window)) {
      items.forEach((el) => el.classList.add('in'));
      return undefined;
    }
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    items.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, [pathname]);
}

export default function Layout() {
  usePageEffects();
  return (
    <>
      <div style={{ position: 'absolute', width: 0, height: 0, overflow: 'hidden' }} aria-hidden="true" dangerouslySetInnerHTML={{ __html: iconSprite }} />
      <Header />
      <main><Outlet /></main>
      <Footer />
    </>
  );
}
