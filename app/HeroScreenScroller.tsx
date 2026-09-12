"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, PointerEvent } from "react";
import { sitePath } from "./site-path";

const heroScreens = [
  {
    label: "Home",
    image: "/screenshots/quilt-home.jpeg",
    alt: "Quilt student home dashboard for Troy High School",
  },
  {
    label: "Posts",
    image: "/screenshots/quilt-club-posts.jpeg",
    alt: "Student Government Association club posts in Quilt",
  },
  {
    label: "Events",
    image: "/screenshots/quilt-events.jpeg",
    alt: "Quilt events calendar month view",
  },
  {
    label: "Parents",
    image: "/screenshots/quilt-parent-dashboard.jpeg",
    alt: "Quilt parent dashboard with linked student information",
  },
  {
    label: "Clubs",
    image: "/screenshots/quilt-club-discovery.jpeg",
    alt: "Quilt discover clubs sheet with search and club list",
  },
];

function getLoopOffset(index: number, activeIndex: number) {
  const half = Math.floor(heroScreens.length / 2);
  let offset = index - activeIndex;

  if (offset > half) offset -= heroScreens.length;
  if (offset < -half) offset += heroScreens.length;

  return offset;
}

export function HeroScreenScroller() {
  const [activeIndex, setActiveIndex] = useState(0);
  const [dragDelta, setDragDelta] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const pauseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [isPaused, setIsPaused] = useState(false);
  const dragStartRef = useRef<{ pointerId: number; startX: number } | null>(null);

  useEffect(() => {
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    if (reducedMotion.matches || isPaused) return undefined;

    const timer = window.setInterval(() => {
      if (pauseTimerRef.current !== null || dragStartRef.current !== null || document.hidden) return;

      setActiveIndex((current) => (current + 1) % heroScreens.length);
    }, 2600);

    return () => window.clearInterval(timer);
  }, [isPaused]);

  useEffect(() => () => {
    if (pauseTimerRef.current !== null) clearTimeout(pauseTimerRef.current);
  }, []);

  const screens = useMemo(
    () =>
      heroScreens.map((screen, index) => ({
        ...screen,
        offset: getLoopOffset(index, activeIndex),
      })),
    [activeIndex],
  );

  function pauseAutoScroll() {
    if (pauseTimerRef.current !== null) clearTimeout(pauseTimerRef.current);
    pauseTimerRef.current = setTimeout(() => { pauseTimerRef.current = null; }, 10000);
  }

  function chooseScreen(index: number) {
    pauseAutoScroll();
    setActiveIndex(index);
  }

  function showAdjacentScreen(direction: -1 | 1) {
    pauseAutoScroll();
    setActiveIndex((current) => (current + direction + heroScreens.length) % heroScreens.length);
  }

  function startDrag(event: PointerEvent<HTMLDivElement>) {
    if (event.pointerType === "mouse" && event.button !== 0) return;

    pauseAutoScroll();
    dragStartRef.current = { pointerId: event.pointerId, startX: event.clientX };
    setIsDragging(true);
    setDragDelta(0);
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function updateDrag(event: PointerEvent<HTMLDivElement>) {
    const dragStart = dragStartRef.current;
    if (!dragStart || dragStart.pointerId !== event.pointerId) return;

    const nextDelta = Math.max(-120, Math.min(120, event.clientX - dragStart.startX));
    setDragDelta(nextDelta);
  }

  function finishDrag(event: PointerEvent<HTMLDivElement>) {
    const dragStart = dragStartRef.current;
    if (!dragStart || dragStart.pointerId !== event.pointerId) return;

    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }

    const finalDelta = event.clientX - dragStart.startX;
    const shouldSwitch = event.type !== "pointercancel" && Math.abs(finalDelta) > 54;
    if (shouldSwitch) showAdjacentScreen(finalDelta < 0 ? 1 : -1);

    dragStartRef.current = null;
    setIsDragging(false);
    setDragDelta(0);
  }

  return (
    <div
      className="screen-scroller"
      style={{ "--drag-x": `${dragDelta}px` } as CSSProperties}
      aria-label="Sample Quilt app screens"
      data-dragging={isDragging ? "true" : undefined}
    >
      <div
        className="screen-scroller-stage"
        onPointerDown={startDrag}
        onMouseEnter={pauseAutoScroll}
        onFocusCapture={pauseAutoScroll}
        onPointerMove={updateDrag}
        onPointerUp={finishDrag}
        onPointerCancel={finishDrag}
      >
        {screens.map((screen) => {
          const isVisible = Math.abs(screen.offset) <= 1;
          const isActive = screen.offset === 0;

          return (
            <figure
              className="screen-card"
              data-offset={screen.offset}
              aria-current={isActive ? "true" : undefined}
              aria-hidden={!isVisible}
              key={screen.label}
            >
              <div className="screen-shot-frame">
                <img src={sitePath(screen.image)} alt={screen.alt} draggable="false" />
              </div>
              <figcaption>{screen.label}</figcaption>
            </figure>
          );
        })}
      </div>
      <div className="screen-dots" aria-label="Choose a sample screen">
        {heroScreens.map((screen, index) => (
          <button
            className={index === activeIndex ? "is-active" : ""}
            type="button"
            aria-label={`Show ${screen.label}`}
            aria-current={index === activeIndex ? "true" : undefined}
            onClick={() => chooseScreen(index)}
            key={screen.label}
          />
        ))}
      </div>
      <button className="screen-motion-toggle" type="button" onClick={() => setIsPaused((paused) => !paused)} aria-pressed={isPaused}>
        {isPaused ? "Resume slideshow" : "Pause slideshow"}
      </button>
    </div>
  );
}
