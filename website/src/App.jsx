import { Link, Route, Routes } from 'react-router-dom';
import Layout from './components/Layout.jsx';
import { usePage } from './components/common.jsx';
import Home from './pages/Home.jsx';
import Features from './pages/Features.jsx';
import HowItWorks from './pages/HowItWorks.jsx';
import ForBrands from './pages/ForBrands.jsx';
import Faq from './pages/Faq.jsx';
import About from './pages/About.jsx';
import Contact from './pages/Contact.jsx';

// Keep these routes in sync with WEBSITE_ROUTES in backend/src/app.js.
function NotFound() {
  usePage('Page not found | Savarun', '');
  return (
    <section className="page-hero" style={{ padding: '120px 0' }}>
      <div className="container">
        <span className="eyebrow">404</span>
        <h1>Page not found</h1>
        <p style={{ marginBottom: 28 }}>The page you're looking for doesn't exist.</p>
        <Link className="btn btn-primary" to="/">Go to home</Link>
      </div>
    </section>
  );
}

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Home />} />
        <Route path="/features" element={<Features />} />
        <Route path="/how-it-works" element={<HowItWorks />} />
        <Route path="/for-brands" element={<ForBrands />} />
        <Route path="/faq" element={<Faq />} />
        <Route path="/about" element={<About />} />
        <Route path="/contact" element={<Contact />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  );
}
