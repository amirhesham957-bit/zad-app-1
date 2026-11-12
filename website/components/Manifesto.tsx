"use client";

import { useRef } from "react";
import { motion, useReducedMotion, useScroll, useTransform, type MotionValue } from "motion/react";

const text =
  "في كل بيت شخصٌ يحمل همّ المال، وما ينقص المطبخ، ومواعيد الدواء، ومن عليه ماذا. صُمّم زاد ليرتاح هذا الشخص.";

function Word({ word, range, progress }: { word: string; range: [number, number]; progress: MotionValue<number> }) {
  const opacity = useTransform(progress, range, [0.15, 1]);
  return (
    <motion.span style={{ opacity }} className="inline-block">
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
    <section className="mx-auto max-w-[1100px] px-4 py-28 md:px-10 md:py-44">
      <p ref={ref} className="display text-5xl leading-[1.25] text-emerald md:text-7xl md:leading-[1.2]">
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
