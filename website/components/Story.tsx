"use client";

import { useRef } from "react";
import { motion, useReducedMotion, useScroll, useTransform, type MotionValue } from "motion/react";
import { CookingPotIcon, PillIcon, UsersThreeIcon, WalletIcon, type Icon } from "@phosphor-icons/react";

type Chapter = {
  icon: Icon;
  title: string;
  line: string;
  // A small real preview of what the feature produces, in the app's own words.
  from: string;
  to: string[];
  glow: string;
};

const chapters: Chapter[] = [
  {
    icon: WalletIcon,
    title: "فلوسك",
    line: "رسالة البنك توصل، وزاد يسجّلها لوحده في الفئة الصح.",
    from: "تم خصم ٢٥٠٫٠٠ ج.م من بطاقتك لدى كارفور",
    to: ["بقالة", "٢٥٠ ج.م", "فاضل لك ١٬٨٤٠ ج.م الشهر ده"],
    glow: "from-carrot/35",
  },
  {
    icon: CookingPotIcon,
    title: "مطبخك",
    line: "صوّر الفاتورة، والمخزن يتملي. اللي بيخلص ينزل في قائمة التسوق.",
    from: "فاتورة: لبن ٢، رز ١ كجم، زيت ١",
    to: ["لبن ٢ علبة", "رز ١ كجم", "الزيت قرب يخلص"],
    glow: "from-leaf/35",
  },
  {
    icon: PillIcon,
    title: "دواك",
    line: "معاد كل جرعة في وقتها، وتنبيه قبل ما العلبة تخلص.",
    from: "أوجمنتين ١ جم، كل ١٢ ساعة",
    to: ["الجرعة الجاية ٩:٠٠ م", "فاضل ٤ أقراص"],
    glow: "from-carrot/30",
  },
  {
    icon: UsersThreeIcon,
    title: "عيلتك",
    line: "مهام وتحديات للأولاد، وشات واحد للبيت كله.",
    from: "مهمة: ترتيب الأوضة قبل المغرب",
    to: ["سلمى خلّصتها", "+٢٠ نقطة"],
    glow: "from-leaf/30",
  },
];

function Panel({ c, index, progress }: { c: Chapter; index: number; progress: MotionValue<number> }) {
  const n = chapters.length;
  const center = index / (n - 1);
  const span = 1 / (n - 1);
  // Offsets must stay inside 0..1: Motion hands scroll-linked opacity/transform
  // to WAAPI, which throws on out-of-range or decreasing keyframe offsets.
  const range = [Math.max(0, center - span), center, Math.min(1, center + span)];
  const scale = useTransform(progress, range, [0.86, 1, 0.86]);
  const opacity = useTransform(progress, range, [0.35, 1, 0.35]);
  const IconC = c.icon;

  return (
    <motion.article
      style={{ scale, opacity }}
      className="relative flex h-[100dvh] w-screen shrink-0 items-center justify-center px-4 md:px-16"
    >
      <div className="grid w-full max-w-[1200px] grid-cols-1 items-center gap-10 md:grid-cols-[1.1fr_1fr]">
        <div>
          <IconC size={56} weight="duotone" className="mb-8 text-carrot" />
          <h3 className="text-6xl font-black leading-[1.1] md:text-8xl">{c.title}</h3>
          <p className="mt-6 max-w-[30ch] text-xl leading-relaxed text-mist md:text-2xl">{c.line}</p>
        </div>

        <div className="relative">
          <div aria-hidden className={`absolute inset-0 -z-10 rounded-[2rem] bg-gradient-to-br ${c.glow} to-transparent blur-3xl`} />
          <div className="glass rounded-[2rem] p-6 md:p-8">
            <p className="rounded-2xl bg-ink/60 p-4 text-sm leading-relaxed text-dim md:text-base">{c.from}</p>
            <div className="my-5 flex items-center gap-3 text-xs font-bold text-carrot-soft">
              <span className="h-px flex-1 bg-gradient-to-l from-carrot/60 to-transparent" />
              زاد فهمها
              <span className="h-px flex-1 bg-gradient-to-r from-carrot/60 to-transparent" />
            </div>
            <div className="flex flex-wrap gap-2">
              {c.to.map((t, i) => (
                <span
                  key={t}
                  className={`rounded-full px-4 py-2 text-sm font-bold md:text-base ${
                    i === 0 ? "bg-carrot text-ink" : "bg-bone/10 text-bone"
                  }`}
                >
                  {t}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </motion.article>
  );
}

export default function Story() {
  const ref = useRef<HTMLElement>(null);
  const reduce = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end end"] });
  const n = chapters.length;
  // RTL: chapters run right to left, so the track moves toward +x.
  const x = useTransform(scrollYProgress, [0, 1], ["0vw", `${(n - 1) * 100}vw`]);
  const bar = useTransform(scrollYProgress, [0, 1], [0, 1]);

  if (reduce) {
    return (
      <section id="story" className="py-24">
        {chapters.map((c, i) => (
          <div key={c.title} className="[&>article]:h-auto [&>article]:w-full [&>article]:py-16">
            <Panel c={c} index={i} progress={scrollYProgress} />
          </div>
        ))}
      </section>
    );
  }

  return (
    <section id="story" ref={ref} className="relative" style={{ height: `${n * 100}dvh` }}>
      <div className="sticky top-0 h-[100dvh] overflow-hidden">
        <h2 className="absolute inset-x-0 top-24 z-10 mx-auto max-w-[1200px] px-4 text-lg font-bold text-dim md:px-16">
          يوم عادي، وزاد شايل عنك أربع حاجات
        </h2>
        <motion.div style={{ x }} className="flex h-full w-max flex-row">
          {chapters.map((c, i) => (
            <Panel key={c.title} c={c} index={i} progress={scrollYProgress} />
          ))}
        </motion.div>
        <div className="absolute inset-x-0 bottom-10 mx-auto h-[2px] max-w-[320px] overflow-hidden rounded-full bg-bone/10">
          <motion.div style={{ scaleX: bar }} className="h-full origin-right bg-carrot" />
        </div>
      </div>
    </section>
  );
}
