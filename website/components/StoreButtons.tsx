"use client";

import { useRef } from "react";
import { motion, useMotionValue, useReducedMotion, useSpring } from "motion/react";
import { AppleLogoIcon, GooglePlayLogoIcon } from "@phosphor-icons/react";
import { APP_STORE_URL, PLAY_STORE_URL } from "@/lib/links";

type Tone = "light" | "green";

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

export function PlayButton({ size = "lg", tone = "light" }: { size?: "sm" | "lg"; tone?: Tone }) {
  const big = size === "lg";
  const paint =
    tone === "green"
      ? "bg-white text-emerald shadow-[0_18px_40px_-14px_rgb(0_0_0/0.45)]"
      : "bg-emerald text-white shadow-[0_18px_40px_-14px_rgb(6_78_59/0.7)]";
  return (
    <Magnetic>
      <a
        href={PLAY_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className={`group relative inline-flex items-center gap-3 overflow-hidden rounded-full font-bold transition-transform duration-300 ease-out-expo active:scale-[0.98] ${paint} ${
          big ? "h-14 ps-6 pe-7 text-base" : "h-11 ps-4 pe-5 text-sm"
        }`}
      >
        <span
          aria-hidden
          className="absolute inset-0 -translate-x-full bg-gradient-to-l from-transparent via-mint-glow/40 to-transparent transition-transform duration-700 ease-out-expo group-hover:translate-x-full"
        />
        <GooglePlayLogoIcon weight="fill" size={big ? 22 : 18} />
        <span className="relative whitespace-nowrap">{big ? "حمّل من Google Play" : "حمّل التطبيق"}</span>
      </a>
    </Magnetic>
  );
}

export function AppStoreSoon({ tone = "light" }: { tone?: Tone }) {
  const paint =
    tone === "green"
      ? "border-white/25 bg-white/10 text-white"
      : "border-hairline bg-surface text-ink shadow-card";
  if (APP_STORE_URL) {
    return (
      <a
        href={APP_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className={`inline-flex h-14 items-center gap-3 rounded-full border ps-6 pe-7 font-bold ${paint}`}
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
      className={`inline-flex h-14 cursor-default items-center gap-3 rounded-full border ps-6 pe-3 ${paint}`}
    >
      <AppleLogoIcon weight="fill" size={22} />
      <span className="whitespace-nowrap font-semibold">App Store</span>
      <span
        className={`rounded-full px-3 py-1 text-xs font-bold ${
          tone === "green" ? "bg-white/15 text-mint-glow" : "bg-mint-50 text-green-700"
        }`}
      >
        قريباً
      </span>
    </span>
  );
}

export function StoreButtons({ tone = "light" }: { tone?: Tone }) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <PlayButton tone={tone} />
      <AppStoreSoon tone={tone} />
    </div>
  );
}
