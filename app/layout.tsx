import type { Metadata } from "next";
import { sitePath } from "./site-path";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const origin = process.env.SITE_URL?.replace(/\/$/, "");
  const socialImage = origin ? `${origin}/og.png` : sitePath("/og.png");

  return {
    title: "Quilt | School Community App",
    description:
      "Quilt brings schedules, clubs, events, QR check-ins, parent views, and school information into one place.",
    icons: {
      icon: sitePath("/favicon.png"),
      shortcut: sitePath("/favicon.png"),
    },
    openGraph: {
      title: "Quilt | School Community App",
      description:
        "Schedules, clubs, events, QR check-ins, parent views, and school information in one school hub.",
      type: "website",
      images: [
        {
          url: socialImage,
          width: 1200,
          height: 630,
          alt: "Quilt school community app preview",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Quilt | School Community App",
      description:
        "A school community app for students, families, clubs, and events.",
      images: [socialImage],
    },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
