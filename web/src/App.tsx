const SUPPORT_EMAIL = "gracefullight.dev@gmail.com";
const PRIVACY_URL =
  "https://sites.google.com/view/volunteerly-privacypolicy/home";
const APP_STORE_URL = "https://testflight.apple.com/join/uSjC9ax3";

const features = [
  {
    emoji: "🔍",
    title: "Discover by interest",
    body: "Browse volunteer programs filtered by your passions, categories, and location, with distance shown for nearby opportunities.",
  },
  {
    emoji: "🤝",
    title: "Join programs you love",
    body: "View full program details — schedule, map, members — and tap once to join and start making an impact.",
  },
  {
    emoji: "💬",
    title: "Community board",
    body: "Every program has a discussion board where volunteers ask questions, share ideas, and coordinate together.",
  },
  {
    emoji: "📣",
    title: "Host your own",
    body: "Create and publish volunteer programs with photos, dates, location, and a volunteer limit in a few taps.",
  },
  {
    emoji: "🔖",
    title: "Save for later",
    body: "Bookmark programs that catch your eye and find them again any time in your saved list.",
  },
  {
    emoji: "🙋",
    title: "Your profile",
    body: "Set your interests and goals, customise your profile, and keep track of your active and past programs.",
  },
];

const steps = [
  {
    n: 1,
    title: "Create your profile",
    body: "Sign up and pick the interests and goals that matter to you.",
  },
  {
    n: 2,
    title: "Discover programs",
    body: "Search and filter volunteer opportunities near you by category.",
  },
  {
    n: 3,
    title: "Join & connect",
    body: "Join the programs you love and chat with fellow volunteers on the board.",
  },
  {
    n: 4,
    title: "Make an impact",
    body: "Show up, contribute, and host your own programs to grow the community.",
  },
];

function Header() {
  return (
    <header className="sticky top-0 z-10 border-b border-ink-100 bg-page/90 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <a href="#top" className="flex items-center gap-3">
          <img
            src="./icon.png"
            alt=""
            width={36}
            height={36}
            className="h-9 w-9 rounded-lg"
          />
          <span className="text-lg font-bold tracking-tight text-ink-900">
            Volunteerly
          </span>
        </a>
        <nav className="flex items-center gap-6 text-sm font-medium text-ink-700">
          <a
            href="#features"
            className="hidden hover:text-brand-dark focus-visible:text-brand-dark sm:inline"
          >
            Features
          </a>
          <a
            href="#how"
            className="hidden hover:text-brand-dark focus-visible:text-brand-dark sm:inline"
          >
            How it works
          </a>
          <a
            href="#support"
            className="rounded-full bg-brand-dark px-4 py-2 text-on-brand transition-colors hover:bg-brand focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-dark"
          >
            Support
          </a>
        </nav>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section
      id="top"
      className="relative overflow-hidden border-b border-ink-100 bg-brand-light/30"
    >
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-6 py-20 md:grid-cols-2 md:py-28">
        <div className="text-center md:text-left">
          <p className="text-sm font-semibold uppercase tracking-widest text-brand-dark">
            Volunteer, together
          </p>
          <h1 className="mt-4 text-4xl font-bold leading-tight tracking-tight text-ink-900 sm:text-5xl">
            Volunteer programs that match your passions
          </h1>
          <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-ink-700 md:mx-0">
            Volunteerly connects you with volunteer programs that fit your
            interests and location. Browse opportunities, join the ones you
            love, host your own, and connect with a community of volunteers.
          </p>
          <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row md:justify-start">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center justify-center rounded-full bg-brand-dark px-7 py-3 text-base font-semibold text-on-brand transition-colors hover:bg-brand focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-dark"
            >
              Join the TestFlight beta
            </a>
            <a
              href="#features"
              className="inline-flex items-center justify-center rounded-full border border-brand-dark px-7 py-3 text-base font-semibold text-brand-dark transition-colors hover:bg-brand-light/40 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-dark"
            >
              See what you can do
            </a>
          </div>
        </div>
        <div className="flex justify-center md:justify-end">
          <div className="rounded-[2rem] bg-page p-8 shadow-xl shadow-brand-dark/10 ring-1 ring-ink-100">
            <img
              src="./icon.png"
              alt="Volunteerly app icon: a hand cradling the Earth"
              width={220}
              height={220}
              className="h-44 w-44 sm:h-56 sm:w-56"
            />
          </div>
        </div>
      </div>
    </section>
  );
}

function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl px-6 py-20">
      <h2 className="text-center text-3xl font-bold tracking-tight text-ink-900">
        Everything you need to start volunteering
      </h2>
      <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-ink-700">
        From discovery to hosting, Volunteerly brings the whole volunteering
        journey into one app.
      </p>
      <ul className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {features.map((f) => (
          <li
            key={f.title}
            className="rounded-2xl border border-ink-100 bg-page p-6 transition-shadow hover:shadow-lg hover:shadow-brand-dark/5"
          >
            <span
              aria-hidden="true"
              className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-light/40 text-2xl"
            >
              {f.emoji}
            </span>
            <h3 className="mt-4 text-lg font-semibold text-ink-900">
              {f.title}
            </h3>
            <p className="mt-2 leading-relaxed text-ink-700">{f.body}</p>
          </li>
        ))}
      </ul>
    </section>
  );
}

function HowItWorks() {
  return (
    <section id="how" className="border-y border-ink-100 bg-on-brand">
      <div className="mx-auto max-w-6xl px-6 py-20">
        <h2 className="text-center text-3xl font-bold tracking-tight text-ink-900">
          How it works
        </h2>
        <ol className="mt-12 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((s) => (
            <li key={s.n} className="text-center sm:text-left">
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-dark text-lg font-bold text-on-brand max-sm:mx-auto">
                {s.n}
              </span>
              <h3 className="mt-4 text-lg font-semibold text-ink-900">
                {s.title}
              </h3>
              <p className="mt-2 leading-relaxed text-ink-700">{s.body}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

function Support() {
  return (
    <section id="support" className="mx-auto max-w-6xl px-6 py-20">
      <div className="rounded-3xl bg-brand-light/30 px-8 py-14 text-center">
        <h2 className="text-3xl font-bold tracking-tight text-ink-900">
          Need help?
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-lg text-ink-700">
          We'd love to hear from you. Reach out with any question, bug report,
          or feedback and we'll get back to you.
        </p>
        <div className="mt-8 flex flex-col items-center justify-center gap-4 sm:flex-row">
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="inline-flex items-center justify-center rounded-full bg-brand-dark px-7 py-3 text-base font-semibold text-on-brand transition-colors hover:bg-brand focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-dark"
          >
            Email support
          </a>
          <a
            href={PRIVACY_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center justify-center rounded-full border border-brand-dark px-7 py-3 text-base font-semibold text-brand-dark transition-colors hover:bg-brand-light/40 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-dark"
          >
            Privacy Policy
          </a>
        </div>
        <p className="mt-6 text-sm text-ink-500">
          Or email us directly at{" "}
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="font-medium text-brand-dark underline underline-offset-4"
          >
            {SUPPORT_EMAIL}
          </a>
        </p>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-ink-100">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 py-8 text-sm text-ink-500 sm:flex-row">
        <div className="flex items-center gap-2">
          <img
            src="./icon.png"
            alt=""
            width={20}
            height={20}
            className="h-5 w-5 rounded"
          />
          <span>Copyright 2026 4sians</span>
        </div>
        <nav className="flex items-center gap-6">
          <a
            href="#support"
            className="hover:text-brand-dark focus-visible:text-brand-dark"
          >
            Support
          </a>
          <a
            href={PRIVACY_URL}
            target="_blank"
            rel="noreferrer"
            className="hover:text-brand-dark focus-visible:text-brand-dark"
          >
            Privacy
          </a>
        </nav>
      </div>
    </footer>
  );
}

export default function App() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Support />
      </main>
      <Footer />
    </>
  );
}
