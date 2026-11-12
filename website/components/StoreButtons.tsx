"use client";

import { useRef } from "react";
import { motion, useMotionValue, useReducedMotion, useSpring } from "motion/react";
import { AppleLogoIcon, GooglePlayLogoIcon } from "@phosphor-icons/react";
import { APP_STORE_URL, PLAY_STORE_URL } from "@/lib/links";

function Magnetic({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();
  const x = useSpring(useMotionValue(0), { stiffness: 160, damping: 14, mass: 0.4 });
  const y = useSpring(useMotionValue(0), { stiffness: 160, damping: 14, mass: 0.4 });

  return (
    <motion.div
      ref={ref}
      style={{ x, y }}
      onPointerMove={(e) => {
        if (reduce || !ref.current || e.pointerType !== "mouse") return;
        const r = ref.current.getBoundingClientRect();
        x.set((e.clientX - (r.left + r.width / 2)) * 0.25);
        y.set((e.clientY - (r.top + r.height / 2)) * 0.35);
      }}
      onPointerLeave={() => {
        x.set(0);
        y.set(0);
      }}
    >
      {children}
    </motion.div>
  );
}

export function PlayButton({ size = "lg" }: { size?: "sm" | "lg" }) {
  const big = size === "lg";
  return (
    <Magnetic>
      <a
        href={PLAY_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className={`group relative inline-flex items-center gap-3 overflow-hidden rounded-full bg-carrot font-bold text-ink shadow-[0_18px_50px_-12px_rgb(240_112_61/0.65)] transition-transform duration-300 ease-out-expo active:scale-[0.98] ${
          big ? "h-14 ps-6 pe-7 text-base" : "h-11 ps-4 pe-5 text-sm"
        }`}
      >
        <span
          aria-hidden
          className="absolute inset-0 -translate-x-full bg-gradient-to-l from-transparent via-white/45 to-transparent transition-transform duration-700 ease-out-expo group-hover:translate-x-full"
        />
        <GooglePlayLogoIcon weight="fill" size={big ? 22 : 18} />
        <span className="relative whitespace-nowrap">
          {big ? "حمّل من Google Play" : "حمّل التطبيق"}
        </span>
      </a>
    </Magnetic>
  );
}

export function AppStoreSoon() {
  if (APP_STORE_URL) {
    return (
      <a
        href={APP_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="glass inline-flex h-14 items-center gap-3 rounded-full ps-6 pe-7 font-bold text-bone"
      >
        <AppleLogoIcon weight="fill" size={22} />
        <span className="whitespace-nowrap">App Store</span>
      </a>
    );
  }
  return (
    <span
      aria-disabled="true"
      title="نسخة الآيفون قريباً"
      className="glass inline-flex h-14 cursor-default items-center gap-3 rounded-full ps-6 pe-3 text-bone/90"
    >
      <AppleLogoIcon weight="fill" size={22} />
      <span className="whitespace-nowrap font-semibold">App Store</span>
      <span className="rounded-full bg-bone/10 px-3 py-1 text-xs font-bold text-carrot-soft">قريباً</span>
    </span>
  );
}

export function StoreButtons() {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <PlayButton />
      <AppStoreSoon />
    </div>
  );
}
