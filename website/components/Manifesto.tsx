"use client";

import { useRef } from "react";
import { motion, useReducedMotion, useScroll, useTransform, type MotionValue } from "motion/react";

const text =
  "كل بيت فيه حد شايل في دماغه الفلوس، والناقص في المطبخ، ومعاد الدوا، ومين عليه إيه. زاد اتعمل عشان الحد ده يرتاح.";

function Word({ word, range, progress }: { word: string; range: [number, number]; progress: MotionValue<number> }) {
  const opacity = useTransform(progress, range, [0.14, 1]);
  const y = useTransform(progress, range, [8, 0]);
  return (
    <motion.span style={{ opacity, y }} className="inline-block">
      {word}&nbsp;
    </motion.span>
  );
}

// Storytelling: the sentence lights up as it is read, at reading pace.
export default function Manifesto() {
  const ref = useRef<HTMLParagraphElement>(null);
  const reduce = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start 0.85", "end 0.45"] });
  const words = text.split(" ");

  return (
    <section className="mx-auto max-w-[1100px] px-4 py-28 md:px-10 md:py-48">
      <p ref={ref} className="text-3xl font-extrabold leading-[1.5] md:text-5xl md:leading-[1.45]">
        {reduce
          ? text
          : words.map((w, i) => (
              <Word
                key={i}
                word={w}
                progress={scrollYProgress}
                range={[i / words.length, (i + 1) / words.length]}
              />
            ))}
      </p>
    </section>
  );
}
