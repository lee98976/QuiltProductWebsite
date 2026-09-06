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

export default function PrivacyPage() {
  return (
    <main>
      <SiteHeader />

      <section className="privacy-hero">
        <p className="eyebrow">Privacy</p>
        <h1>Quilt Privacy</h1>
        <p>
          Last updated August 15, 2026. This draft describes the main information
          Quilt uses to support school schedules, clubs, events, QR check-ins,
          parent connections, moderation, and account-based access.
        </p>
      </section>

      <section className="privacy-content" aria-label="Privacy details">
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
          <h2>Use this section for your final contact details.</h2>
          <p>
            Add the official Quilt support email, project owner, school contact,
            or district contact here before publishing the policy as final.
          </p>
        </div>
        <Link className="secondary-action" href="/">Back to Quilt</Link>
      </section>
    </main>
  );
}
