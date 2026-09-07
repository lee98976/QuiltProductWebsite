import { DemoFocus } from "./DemoFocus";
import { HeroScreenScroller } from "./HeroScreenScroller";
import { SiteHeader } from "./SiteHeader";
import { sitePath } from "./site-path";

const previewSamples = {
  schools: ["Troy High School", "Sunset Ridge High School", "Northview Preparatory"],
  clubs: ["Art Collective", "Debate Society", "Environmental Action Club", "Robotics Lab", "Health Sciences HOSA"],
  people: ["Maya Chen", "Jordan Patel", "Sofia Martinez", "Ethan Brooks", "Ava Nguyen", "Noah Kim"],
};

const featureGroups = [
  {
    eyebrow: "Manage",
    title: "Bring the school day into one system.",
    description:
      "Schedules, clubs, events, QR check-ins, notifications, parent connections, and school information live in one role-aware app.",
    items: ["Bell schedules", "Club spaces", "Event calendars", "Parent views"],
  },
  {
    eyebrow: "Drive",
    title: "Make participation easier to find and track.",
    description:
      "Students can discover clubs, follow updates, vote in polls, add events to calendars, and check in with QR codes.",
    items: ["Club discovery", "Polls", "Calendar links", "Attendance QR"],
  },
  {
    eyebrow: "Recognize",
    title: "Give leaders and schools cleaner oversight.",
    description:
      "Club roles, visibility controls, moderation reports, admin tools, and shared files support safer school operations.",
    items: ["Role permissions", "Reports", "Admin portal", "Shared files"],
  },
];

const appRows = [
  ["Home", "Troy High dashboard, quick actions, today card, and upcoming events"],
  ["Clubs", "Joined clubs, Discover Clubs sheet, club requests, posts, polls, events"],
  ["Events", "Upcoming Event, School Polls, My Events, filters, and month calendar"],
  ["Profile", "Verified profile card, Hall Pass, Family, Schedule, and Settings"],
  ["Admin", "School tools for clubs, moderation, students, and requests"],
];

const storeButtons = [
  { label: "App Store", eyebrow: "Coming soon on", icon: "A" },
  { label: "Google Play", eyebrow: "Coming soon on", icon: "G" },
];

export default function Home() {
  return (
    <main>
      <SiteHeader />

      <section id="top" className="school-hero">
        <div className="school-hero-copy">
          <h1>Take school community to the next level.</h1>
          <p>
            Quilt helps students, families, club leaders, and school administrators keep
            schedules, events, clubs, check-ins, and communication connected.
          </p>
          <div className="hero-actions">
            <a className="primary-action" href="#features">View Features</a>
            <a className="watch-action" href="#demo">◉ See in action</a>
          </div>
          <div className="store-actions" aria-label="App download links coming soon">
            {storeButtons.map((store) => (
              <button className="store-badge" type="button" disabled key={store.label}>
                <span className="store-icon" aria-hidden="true">{store.icon}</span>
                <span>
                  <small>{store.eyebrow}</small>
                  <strong>{store.label}</strong>
                </span>
              </button>
            ))}
          </div>
        </div>
        <div className="school-hero-art">
          <HeroScreenScroller />
        </div>
      </section>

      <section id="features" className="feature-band">
        {featureGroups.map((feature) => (
          <article className="feature-tile" key={feature.title}>
            <p className="eyebrow">{feature.eyebrow}</p>
            <h2>{feature.title}</h2>
            <p>{feature.description}</p>
            <ul>
              {feature.items.map((item) => <li key={item}>{item}</li>)}
            </ul>
          </article>
        ))}
      </section>

      <section id="demo" className="flutter-demo-section">
        <div className="section-heading">
          <p className="eyebrow">App Preview</p>
          <h2>See how Quilt fits into the school day.</h2>
          <p>
            Explore a guided look at the student, family, club, and school workflows
            that help people stay connected around schedules, events, and activities.
          </p>
        </div>
        <DemoFocus>
            <h3>A closer look at Quilt</h3>
            <p>
              The preview shows representative schools, clubs, and people so families
              and school teams can understand the experience before rollout.
            </p>
            <div className="demo-sample-grid" aria-label="Sample preview content">
              <div>
                <strong>Sample schools</strong>
                {previewSamples.schools.map((school) => <span key={school}>{school}</span>)}
              </div>
              <div>
                <strong>Sample clubs</strong>
                {previewSamples.clubs.map((club) => <span key={club}>{club}</span>)}
              </div>
              <div>
                <strong>Sample people</strong>
                {previewSamples.people.map((person) => <span key={person}>{person}</span>)}
              </div>
            </div>
        </DemoFocus>
      </section>

      <section id="roles" className="role-section">
        <div className="section-heading">
          <p className="eyebrow">Role-Based App</p>
          <h2>Different users see the parts of Quilt that fit their role.</h2>
        </div>
        <div className="role-columns">
          <div><h3>Students</h3><p>Use the dashboard, follow clubs, vote in polls, add events to calendars, scan QR codes, and manage hall passes.</p></div>
          <div><h3>Club Leaders</h3><p>Create posts, attach files, publish events, run polls, manage quick links, and use permissioned roles.</p></div>
          <div><h3>Parents</h3><p>Connect to students, view activity, follow events, and see volunteer context through a family dashboard.</p></div>
          <div><h3>Schools</h3><p>Manage clubs, schedules, users, notifications, reports, and administrator assignments.</p></div>
        </div>
      </section>

      <section className="section app-map">
        <div className="section-heading">
          <p className="eyebrow">App Map</p>
          <h2>What Quilt brings together.</h2>
        </div>
        <div className="map-table">
          {appRows.map(([area, detail]) => (
            <div className="map-row" key={area}>
              <strong>{area}</strong>
              <span>{detail}</span>
            </div>
          ))}
        </div>
      </section>

      <section id="privacy" className="privacy-callout">
        <div>
          <p className="eyebrow">Privacy</p>
          <h2>Designed for school communities.</h2>
          <p>
            Quilt uses role-based access, visibility controls, and moderation workflows
            so students, families, and staff see the information meant for them.
          </p>
        </div>
        <a className="primary-action" href={sitePath("/privacy/")}>Open privacy page</a>
      </section>

      <footer>
        <span>Quilt</span>
        <span>School life, stitched together.</span>
      </footer>
    </main>
  );
}
