"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { sitePath } from "./site-path";

const navItems = [
  { label: "Products", href: "/#features" },
  { label: "Services", href: "/#roles" },
  { label: "Preview", href: "/#demo" },
  { label: "Privacy", href: "/privacy" },
];

export function SiteHeader() {
  const [isFloating, setIsFloating] = useState(false);
  const headerRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const header = headerRef.current;
    if (!header) return;
    const observer = new ResizeObserver(() => {
      document.documentElement.style.setProperty(
        "--marketing-header-offset", `${header.getBoundingClientRect().height}px`,
      );
    });
    observer.observe(header);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    function updateFloatingState() {
      setIsFloating(window.scrollY > 8);
    }

    updateFloatingState();
    window.addEventListener("scroll", updateFloatingState, { passive: true });

    return () => window.removeEventListener("scroll", updateFloatingState);
  }, []);

  return (
    <header ref={headerRef} className={`marketing-header${isFloating ? " is-floating" : ""}`}>
      <Link className="marketing-brand" href="/" aria-label="Quilt home">
        <span className="brand-mark">Q</span>
        <span>Quilt</span>
      </Link>
      <nav aria-label="Primary navigation">
        {navItems.map((item) => (
          <a href={sitePath(item.href === "/privacy" ? "/privacy/" : item.href)} key={item.label}>
            {item.label}
          </a>
        ))}
      </nav>
    </header>
  );
}
