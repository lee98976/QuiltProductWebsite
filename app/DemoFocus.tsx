"use client";

import { useEffect, useRef } from "react";
import type { ReactNode } from "react";
import { sitePath } from "./site-path";

const PHONE_WIDTH = 390;
const PHONE_HEIGHT = 844;

export function DemoFocus({ children }: { children: ReactNode }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const slotRef = useRef<HTMLDivElement>(null);
  const phoneRef = useRef<HTMLDivElement>(null);
  const openerRef = useRef<HTMLButtonElement>(null);
  const animationRef = useRef<Animation | null>(null);
  const closingRef = useRef(false);
  const originalOverflow = useRef<string | null>(null);

  function restoreScroll() {
    if (originalOverflow.current !== null) {
      document.body.style.overflow = originalOverflow.current;
      originalOverflow.current = null;
    }
  }

  function layoutPhone() {
    const dialog = dialogRef.current;
    const slot = slotRef.current;
    const phone = phoneRef.current;
    if (!dialog || !slot || !phone) return;
    const inlineScale = slot.clientWidth / PHONE_WIDTH;
    slot.style.height = `${PHONE_HEIGHT * inlineScale}px`;
    const scale = dialog.open
      ? Math.min((window.innerHeight - 24) / PHONE_HEIGHT, (window.innerWidth - 24) / PHONE_WIDTH)
      : inlineScale;
    phone.style.setProperty("--phone-scale", String(Math.max(0.1, scale)));
  }

  useEffect(() => {
    const observer = new ResizeObserver(layoutPhone);
    if (slotRef.current) observer.observe(slotRef.current);
    window.addEventListener("resize", layoutPhone);
    layoutPhone();
    return () => {
      observer.disconnect();
      window.removeEventListener("resize", layoutPhone);
      animationRef.current?.cancel();
      restoreScroll();
    };
  }, []);

  function animatePhone(from: DOMRect, to: DOMRect, reverse = false) {
    const phone = phoneRef.current;
    if (!phone || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return null;
    const endScale = to.width / PHONE_WIDTH;
    const startTransform = `translate(${from.left - to.left}px, ${from.top - to.top}px) scale(${from.width / PHONE_WIDTH})`;
    const endTransform = `scale(${endScale})`;
    const animation = phone.animate(
      [{ transform: startTransform }, { transform: endTransform }],
      { duration: 480, easing: "cubic-bezier(0.22, 1, 0.36, 1)", direction: reverse ? "reverse" : "normal", fill: "both" },
    );
    animationRef.current = animation;
    return animation;
  }

  function openPreview() {
    const dialog = dialogRef.current;
    const phone = phoneRef.current;
    if (!dialog || !phone || dialog.open) return;
    animationRef.current?.cancel();
    const from = phone.getBoundingClientRect();
    originalOverflow.current = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    dialog.showModal();
    layoutPhone();
    const animation = animatePhone(from, phone.getBoundingClientRect());
    if (animation) animation.onfinish = () => animation.cancel();
  }

  function closePreview() {
    const dialog = dialogRef.current;
    const phone = phoneRef.current;
    const slot = slotRef.current;
    if (!dialog?.open || !phone || !slot || closingRef.current) return;
    closingRef.current = true;
    animationRef.current?.cancel();
    const animation = animatePhone(slot.getBoundingClientRect(), phone.getBoundingClientRect(), true);
    const finish = () => {
      dialog.close();
      animation?.cancel();
      closingRef.current = false;
      restoreScroll();
      layoutPhone();
      openerRef.current?.focus({ preventScroll: true });
    };
    if (animation) animation.onfinish = finish;
    else finish();
  }

  return (
    <div className="flutter-demo-shell">
      <div className="phone-demo-slot" ref={slotRef}>
        {/* Keep one iframe mounted, with a constant viewport, during expansion. */}
        <dialog
          className="demo-preview-dialog"
          ref={dialogRef}
          aria-label="Expanded Quilt app preview"
          onCancel={(event) => { event.preventDefault(); closePreview(); }}
        >
          <button className="demo-focus-close" type="button" aria-label="Close expanded preview" onClick={closePreview}>×</button>
          <div className="phone-preview-position">
            <div className="flutter-phone-frame scroll-contained-demo" ref={phoneRef}>
              <div className="phone-screen">
                <div className="phone-status-bar" aria-hidden="true">
                  <span>2:51</span>
                  <span className="phone-status-icons">
                    <span className="phone-signal"><i /><i /><i /></span>
                    <span className="phone-wifi" />
                    <span className="phone-battery">97</span>
                  </span>
                </div>
                <iframe title="Quilt app preview" src={sitePath("/flutter-demo/index.html")} loading="lazy" allow="camera; clipboard-read; clipboard-write" />
              </div>
            </div>
          </div>
        </dialog>
      </div>
      <aside className="demo-explainer">
        {children}
        <button className="primary-action" type="button" onClick={openPreview} ref={openerRef}>Open larger preview</button>
      </aside>
    </div>
  );
}
