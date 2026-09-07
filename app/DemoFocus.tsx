"use client";

import { useEffect, useRef } from "react";
import type { ReactNode } from "react";
import { sitePath } from "./site-path";

export function DemoFocus({ children }: { children: ReactNode }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const openerRef = useRef<HTMLButtonElement>(null);
  const originalOverflow = useRef<string | null>(null);

  function restoreScroll() {
    if (originalOverflow.current !== null) {
      document.body.style.overflow = originalOverflow.current;
      originalOverflow.current = null;
    }
  }

  useEffect(() => restoreScroll, []);

  function openPreview() {
    const dialog = dialogRef.current;
    if (!dialog || dialog.open) return;
    originalOverflow.current = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    dialog.showModal();
  }

  function closePreview() {
    dialogRef.current?.close();
  }

  return (
    <div className="flutter-demo-shell">
      <div className="phone-demo-slot">
        {/* The same iframe stays mounted in both views, preserving demo state.
            showModal supplies focus containment and makes the page inert. */}
        <dialog
          className="demo-preview-dialog"
          ref={dialogRef}
          aria-label="Expanded Quilt app preview"
          onClose={() => {
            restoreScroll();
            openerRef.current?.focus({ preventScroll: true });
          }}
        >
          <button
            className="demo-focus-close"
            type="button"
            aria-label="Close expanded preview"
            onClick={closePreview}
          >
            ×
          </button>
          <div className="flutter-phone-frame scroll-contained-demo">
            <div className="phone-screen">
              <div className="phone-status-bar" aria-hidden="true">
                <span>2:51</span>
                <span className="phone-status-icons">
                  <span className="phone-signal"><i /><i /><i /></span>
                  <span className="phone-wifi" />
                  <span className="phone-battery">97</span>
                </span>
              </div>
              <iframe
                title="Quilt app preview"
                src={sitePath("/flutter-demo/index.html")}
                loading="lazy"
                allow="camera; clipboard-read; clipboard-write"
              />
            </div>
          </div>
        </dialog>
      </div>
      <aside className="demo-explainer">
        {children}
        <button className="primary-action" type="button" onClick={openPreview} ref={openerRef}>
          Open larger preview
        </button>
      </aside>
    </div>
  );
}
