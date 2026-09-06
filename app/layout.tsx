import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const headerStore = await headers();
  const host = headerStore.get("x-forwarded-host") ?? headerStore.get("host") ?? "localhost:3000";
  const protocol = headerStore.get("x-forwarded-proto") ?? (host.includes("localhost") ? "http" : "https");
  const origin = `${protocol}://${host}`;

  return {
    title: "Quilt | School Community App",
    description:
      "Quilt brings schedules, clubs, events, QR check-ins, parent views, and school information into one place.",
    icons: {
      icon: "/favicon.png",
      shortcut: "/favicon.png",
    },
    openGraph: {
      title: "Quilt | School Community App",
      description:
        "Schedules, clubs, events, QR check-ins, parent views, and school information in one school hub.",
      type: "website",
      images: [
        {
          url: `${origin}/og.png`,
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
      images: [`${origin}/og.png`],
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
