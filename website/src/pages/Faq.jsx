import { usePage, Cta, PageHero, Faq as Q, EMAIL } from '../components/common.jsx';
import { Link } from 'react-router-dom';

function Group({ title, children }) {
  return (
    <div className="faq-group reveal">
      <h3>{title}</h3>
      <div className="faq-list">{children}</div>
    </div>
  );
}

export default function Faq() {
  usePage(
    'FAQ | Savarun AI Outfit Stylist',
    'Answers about Savarun: the Fit Score, how outfit photos are handled, the digital wardrobe, community safety, the Shop and brands, and deleting your account.',
  );
  return (
    <>
      <PageHero crumb="FAQ" eyebrow="Help centre" title={<>Frequently asked <span className="accent">questions</span></>}>
        Can't find your answer? Email us at <a href={`mailto:${EMAIL}`}>{EMAIL}</a>.
      </PageHero>

      <section>
        <div className="container">
          <Group title="About Savarun">
            <Q q="What is Savarun?">Savarun is an AI fashion app. Take a photo of your outfit to get a Fit Score, Style DNA and stylist advice, keep a digital wardrobe, share looks with a style community and shop products from approved brands.</Q>
            <Q q="Is it free?">Yes. Savarun is free to use and has no ads. When you buy something from the Shop, you pay the brand on its own website.</Q>
            <Q q="Who can use Savarun, and on which phones?">Savarun is for people aged 18 and over. It is coming soon to Google Play for Android, and to the App Store for iPhone. You can log in with Google or with your phone number and a one-time code; Sign in with Apple is planned for iPhone.</Q>
          </Group>

          <Group title="AI analysis & photo privacy">
            <Q q="How is my Fit Score calculated?">The AI looks at your clothing type, colours, pattern, fabric, fit and accessories, then rates five factors: Trend Match (30%), Color Harmony (20%), Style Consistency (20%), Silhouette Balance (15%) and Accessories (15%). The weighted total is your score from 0 to 100. Our team may fine-tune these weights as trends change.</Q>
            <Q q="What is Style DNA?">It is a breakdown of the styles your outfit is made of, in percentages, for example Streetwear 70%, Minimalist 20%, Athleisure 10%.</Q>
            <Q q="Who sees my outfit photos?">Your photo is sent securely to OpenAI's GPT-4o vision model for analysis. Under OpenAI's API data policy, data sent through its API is not used to train its models. Your analyses are saved to your outfit history; other people only see outfits you choose to share. Read the <a href="/privacy-policy">Privacy Policy</a>.</Q>
            <Q q="Is the AI always right?">No. The Fit Score and advice are AI-generated suggestions to help you think about your look, not a final judgement. Style is personal: wear what makes you feel good.</Q>
          </Group>

          <Group title="Wardrobe">
            <Q q="How do I add clothes?">Open the Wardrobe and add an item with your camera, or upload many photos at once from your gallery. The AI tags each item with its category, colour (with hex code), fabric, season and formality. You can edit the tags.</Q>
            <Q q="Can other people see my wardrobe?">Only if you want them to. You can keep your wardrobe private or make it public with the Public Wardrobe switch in Settings.</Q>
          </Group>

          <Group title="Community & safety">
            <Q q="Can strangers message me?">No. Someone has to send you a chat request first, and you only chat 1-on-1 after you accept it.</Q>
            <Q q="How do I report or block someone?">Use the report or block option on any user, post or message. Blocking someone hides them from your Explore and stops chat between you. Our team reviews reports within 24 hours and can remove content or ban accounts. See our <a href="/child-safety">Child Safety Standards</a>.</Q>
          </Group>

          <Group title="Shop & brands">
            <Q q="Do I buy products inside the app?">No. Tapping a product opens the brand's own website, where you buy directly from the brand. Payment, delivery and returns are handled by the brand.</Q>
            <Q q="How can my brand sell on Savarun?">Open the Shop tab, tap "Sell" and apply with your brand name and website. Our team reviews every brand. It's free to apply. More on the <Link to="/for-brands">For Brands</Link> page.</Q>
          </Group>

          <Group title="Account & deletion">
            <Q q="How do I delete my account?">In the app, go to Settings, then Delete Account. You can also request deletion on our <a href="/account-deletion">Delete Account</a> page without opening the app.</Q>
          </Group>
        </div>
      </section>

      <Cta />
    </>
  );
}
