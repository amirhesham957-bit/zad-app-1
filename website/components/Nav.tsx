"use client";

import Image from "next/image";
import { motion, useMotionValueEvent, useReducedMotion, useScroll } from "motion/react";
import { useState } from "react";
import { PlayButton } from "./StoreButtons";

const links = [
  { href: "#story", label: "إزاي بيشتغل" },
  { href: "#brain", label: "عقل زاد" },
  { href: "#download", label: "التحميل" },
];

export default function Nav() {
  const { scrollY } = useScroll();
  const reduce = useReducedMotion();
  // Only flips once past the threshold, so this re-renders twice, not per frame.
  const [solid, setSolid] = useState(false);
  useMotionValueEvent(scrollY, "change", (v) => {
    const next = v > 40;
    if (next !== solid) setSolid(next);
  });

  return (
    <motion.header
      initial={reduce ? false : { y: -40, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.9, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
      className="fixed inset-x-0 top-0 z-50 px-4 pt-4 md:px-10"
    >
      <nav
        className={`mx-auto flex h-16 max-w-[1400px] items-center justify-between rounded-full ps-5 pe-2 transition-all duration-500 ${
          solid ? "glass" : "border border-transparent"
        }`}
      >
        <a href="#top" className="flex items-center gap-2" aria-label="زاد، الرئيسية">
          <Image src="/carrot_logo.svg" alt="" width={34} height={34} priority />
          <span className="text-2xl font-black tracking-tight">زاد</span>
        </a>
        <ul className="hidden items-center gap-8 text-sm text-mist md:flex">
          {links.map((l) => (
            <li key={l.href}>
              <a href={l.href} className="transition-colors hover:text-bone">
                {l.label}
              </a>
            </li>
          ))}
        </ul>
        <PlayButton size="sm" />
      </nav>
    </motion.header>
  );
}
