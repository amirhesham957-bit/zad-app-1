"use client";

import dynamic from "next/dynamic";
import { useRef } from "react";
import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import { StoreButtons } from "./StoreButtons";

const HeroScene = dynamic(() => import("./three/HeroScene"), {
  ssr: false,
  loading: () => (
    <div className="flex h-full w-full items-center justify-center">
      <div className="h-56 w-56 animate-pulse rounded-full bg-carrot/15 blur-2xl" />
    </div>
  ),
});

const ease = [0.16, 1, 0.3, 1] as const;

export default function Hero() {
  const ref = useRef<HTMLElement>(null);
  const reduce = useReducedMotion() ?? false;
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  const sceneY = useTransform(scrollYProgress, [0, 1], ["0%", reduce ? "0%" : "22%"]);
  const sceneScale = useTransform(scrollYProgress, [0, 1], [1, reduce ? 1 : 0.86]);
  const copyY = useTransform(scrollYProgress, [0, 1], ["0%", reduce ? "0%" : "-30%"]);
  const fade = useTransform(scrollYProgress, [0, 0.75], [1, 0]);

  const line = (delay: number) => ({
    initial: reduce ? false : { y: "110%" },
    animate: { y: "0%" },
    transition: { duration: 1.1, delay, ease },
  });

  return (
    <section ref={ref} className="relative isolate min-h-[100dvh] overflow-hidden pt-24">
      {/* Atmosphere */}
      <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute -top-40 left-[-10%] h-[70vh] w-[70vh] rounded-full bg-carrot/20 blur-[140px]" />
        <div className="absolute bottom-[-20%] right-[-10%] h-[60vh] w-[60vh] rounded-full bg-leaf/15 blur-[140px]" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,transparent_40%,var(--color-ink)_85%)]" />
      </div>

      <motion.div
        style={{ y: sceneY, scale: sceneScale }}
        initial={reduce ? false : { opacity: 0, scale: 0.92 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 1.6, delay: 0.1, ease }}
        className="absolute inset-0 -z-[5]"
      >
        <HeroScene reduced={reduce} />
      </motion.div>

      <div className="mx-auto grid min-h-[calc(100dvh-6rem)] max-w-[1400px] grid-cols-1 items-end px-4 md:px-10 lg:grid-cols-2 lg:items-center">
        <motion.div style={{ y: copyY, opacity: fade }} className="relative z-10 pb-12 pt-[38vh] lg:pb-0 lg:pt-0">
          <motion.p
            initial={reduce ? false : { opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.9, delay: 0.15, ease }}
            className="mb-6 inline-flex items-center gap-2 rounded-full border border-line px-4 py-1.5 text-sm text-mist"
          >
            من <span className="font-bold text-bone">أسترا لاب</span>
          </motion.p>

          <h1 className="text-[2.6rem] font-black leading-[1.15] tracking-tight text-bone sm:text-6xl lg:text-7xl">
            <span className="block overflow-hidden pb-2">
              <motion.span className="block" {...line(0.25)}>
                بيتك كله،
              </motion.span>
            </span>
            <span className="block overflow-hidden pb-2">
              <motion.span className="block" {...line(0.38)}>
                في <span className="text-carrot">عقل واحد.</span>
              </motion.span>
            </span>
          </h1>

          <motion.p
            initial={reduce ? false : { opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, delay: 0.6, ease }}
            className="mt-6 max-w-[34ch] text-lg leading-relaxed text-mist sm:text-xl"
          >
            زاد بيسجّل مصاريفك من رسايل البنك، بيعرف ناقص إيه في المطبخ، وبيفكّرك بمعاد الدوا.
          </motion.p>

          <motion.div
            initial={reduce ? false : { opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, delay: 0.75, ease }}
            className="mt-10"
          >
            <StoreButtons />
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
