"use client";

import { motion, useReducedMotion } from "motion/react";
import { StoreButtons } from "./StoreButtons";
import Zado from "./Zado";

export default function Download() {
  const reduce = useReducedMotion();
  return (
    <section id="download" className="px-4 pb-20 md:px-10">
      <motion.div
        initial={reduce ? false : { opacity: 0, y: 60 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
        className="relative mx-auto max-w-[1400px] overflow-hidden rounded-[2.5rem] bg-gradient-to-br from-green-700 to-emerald-deep px-6 py-16 text-white md:px-16 md:py-24"
      >
        <div
          aria-hidden
          className="pointer-events-none absolute -bottom-1/3 start-1/2 h-[90%] w-[70%] rounded-full bg-[radial-gradient(closest-side,rgb(110_231_183/0.35),transparent)]"
        />
        <div className="relative grid grid-cols-1 items-center gap-10 md:grid-cols-[1.4fr_1fr]">
          <div>
            <h2 className="display text-7xl leading-[0.95] md:text-[9rem]">
              دع زاد <span className="text-mint-glow">يحمل عنك.</span>
            </h2>
            <p className="mt-6 max-w-[36ch] text-lg text-white/80 md:text-xl">
              مجاني على أندرويد الآن، ونسخة الآيفون قريباً.
            </p>
            <div className="mt-10">
              <StoreButtons tone="green" />
            </div>
          </div>
          <div className="mx-auto h-56 md:h-80">
            <Zado mood="love" className="aspect-[240/264] h-full" />
          </div>
        </div>
      </motion.div>
    </section>
  );
}
