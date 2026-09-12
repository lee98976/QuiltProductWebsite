import { SiteHeader } from "../SiteHeader";
import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Quilt Privacy | Quilt",
  description: "A draft overview of information used by Quilt's school community features.",
};

const privacySections = [
  {
    title: "Information Quilt Uses",
    body:
      "Quilt may use account information from Google sign-in, school affiliation, account role, profile details, club memberships, event activity, parent-student links, notifications, uploaded files, reports, and QR scan activity needed to run school features.",
  },
  {
    title: "How Information Supports the App",
    body:
      "The app uses information to show the right dashboard, load schedules, display clubs and events, manage posts and polls, connect parents with students, support calendar actions, process QR check-ins, and help school or club leaders manage participation.",
  },
  {
    title: "Student, Parent, and Prospective Views",
    body:
      "Quilt is built around role-based access. Current students can participate in school and club activity, parents receive a view-only family dashboard, and prospective students can browse public school or club information while protected participation features stay unavailable.",
  },
  {
    title: "Uploads and Shared Content",
    body:
      "Club posts and school activity may include file attachments, links, images, polls, event descriptions, locations, and other shared content. Users should avoid sharing sensitive personal information unless it is needed for the school activity.",
  },
  {
    title: "QR Check-Ins and Hall Passes",
    body:
      "QR scanning can be used for club attendance, event attendance, and hall pass room codes. These scans may create records that help the school confirm participation, location-based actions, or timing.",
  },
  {
    title: "Safety and Moderation",
    body:
      "Quilt includes visibility settings, club roles, report workflows, and admin tools intended to keep school content appropriate and limited to the right audience.",
  },
  {
    title: "Connected Services",
    body:
      "Some features may use secure sign-in, file storage, or calendar links for Google, Apple, Outlook, or compatible calendar apps.",
  },
  {
    title: "Changes",
    body:
      "This privacy page may be updated as Quilt changes. The latest version should be kept with the Quilt product website so students, families, and school staff can review it in one place.",
  },
];

const privacyHighlights = [
  "Role-aware access",
  "School and family views",
  "Moderation workflows",
];

export default function PrivacyPage() {
  return (
    <main>
      <SiteHeader />

      <section className="privacy-hero">
        <div className="privacy-hero-copy">
          <p className="eyebrow">Privacy</p>
          <h1>Quilt Privacy</h1>
          <p>
            A clear view of how Quilt handles the information that keeps school
            schedules, clubs, events, QR check-ins, parent connections,
            moderation, and account-based access working.
          </p>
        </div>
        <aside className="privacy-policy-card" aria-label="Privacy policy summary">
          <span>Last updated</span>
          <strong>August 15, 2026</strong>
          <ul>
            {privacyHighlights.map((highlight) => (
              <li key={highlight}>{highlight}</li>
            ))}
          </ul>
        </aside>
      </section>

      <section className="privacy-content" aria-labelledby="privacy-details-title">
        <div className="section-heading privacy-section-heading">
          <p className="eyebrow">Policy Overview</p>
          <h2 id="privacy-details-title">Built for school communities.</h2>
          <p>
            Quilt only works when students, families, and staff can trust that
            each view is shaped around their role and the school context they
            belong to.
          </p>
        </div>
        {privacySections.map((section) => (
          <article key={section.title}>
            <h2>{section.title}</h2>
            <p>{section.body}</p>
          </article>
        ))}
      </section>

      <section id="contact" className="privacy-callout">
        <div>
          <p className="eyebrow">Questions</p>
          <h2>Questions about Quilt privacy?</h2>
          <p>
            Contact Quilt support at{" "}
            <a href="mailto:quilt.support@gmail.com">quilt.support@gmail.com</a>
            .
          </p>
        </div>
        <Link className="secondary-action" href="/">Back to Quilt</Link>
      </section>
    </main>
  );
}
