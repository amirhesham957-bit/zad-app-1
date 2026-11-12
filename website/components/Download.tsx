"use client";

import Image from "next/image";
import { motion, useReducedMotion } from "motion/react";
import { StoreButtons } from "./StoreButtons";

export default function Download() {
  const reduce = useReducedMotion();
  return (
    <section id="download" className="px-4 pb-24 md:px-10">
      <motion.div
        initial={reduce ? false : { opacity: 0, scale: 0.94 }}
        whileInView={{ opacity: 1, scale: 1 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 1.1, ease: [0.16, 1, 0.3, 1] }}
        className="relative mx-auto max-w-[1400px] overflow-hidden rounded-[2.5rem] border border-line bg-ink-2 px-6 py-20 md:px-16 md:py-28"
      >
        <div aria-hidden className="pointer-events-none absolute inset-0">
          <div className="absolute -bottom-1/2 left-1/2 h-[120%] w-[120%] -translate-x-1/2 rounded-full bg-[radial-gradient(closest-side,rgb(240_112_61/0.35),transparent)]" />
          <div className="absolute inset-0 bg-[linear-gradient(to_bottom,transparent,rgb(7_13_10/0.4))]" />
        </div>

        <div className="relative grid grid-cols-1 items-center gap-12 md:grid-cols-[1.4fr_1fr]">
          <div>
            <h2 className="text-5xl font-black leading-[1.15] md:text-7xl">
              خلّي زاد <span className="text-carrot">يشيل عنك.</span>
            </h2>
            <p className="mt-6 max-w-[36ch] text-lg text-mist md:text-xl">
              مجاني على أندرويد دلوقتي. نسخة الآيفون في الطريق.
            </p>
            <div className="mt-10">
              <StoreButtons />
            </div>
          </div>

          <motion.div
            animate={reduce ? undefined : { y: [0, -14, 0], rotate: [-6, -3, -6] }}
            transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }}
            className="mx-auto w-44 md:w-64"
          >
            <Image
              src="/carrot_logo.svg"
              alt="شعار زاد"
              width={256}
              height={256}
              className="h-auto w-full drop-shadow-[0_40px_60px_rgb(240_112_61/0.45)]"
            />
          </motion.div>
        </div>
      </motion.div>
    </section>
  );
}
