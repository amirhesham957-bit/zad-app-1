"use client";

import { useRef, useState } from "react";
import {
  motion,
  useMotionValueEvent,
  useReducedMotion,
  useScroll,
  useTransform,
} from "motion/react";
import Zado, { type ZadoMood, type ZadoProp } from "./Zado";

type Chapter = {
  title: string;
  line: string;
  // A small real preview of what the feature produces, in the app's own words.
  from: string;
  to: string[];
  bg: string;
  chip: string;
  mood: ZadoMood;
  prop: ZadoProp;
};

const chapters: Chapter[] = [
  {
    title: "أموالك",
    line: "تصل رسالة البنك، فيسجّلها زاد تلقائياً في الفئة الصحيحة.",
    from: "تم خصم ٢٥٠٫٠٠ ر.س من بطاقتك لدى بنده",
    to: ["بقالة", "٢٥٠ ر.س", "المتبقي ١٬٨٤٠ ر.س هذا الشهر"],
    bg: "#E6F4EC",
    chip: "#064E3B",
    mood: "idle",
    prop: "coin",
  },
  {
    title: "مطبخك",
    line: "صوّر الفاتورة فيمتلئ المخزون، وما ينفد ينتقل إلى قائمة التسوق.",
    from: "فاتورة: حليب ٢، رز ١ كجم، زيت ١",
    to: ["حليب ٢ علبة", "رز ١ كجم", "الزيت أوشك على النفاد"],
    bg: "#FBF0D9",
    chip: "#C68216",
    mood: "happy",
    prop: "chef",
  },
  {
    title: "دواؤك",
    line: "موعد كل جرعة في وقته، وتنبيه قبل أن تنفد العلبة.",
    from: "أوجمنتين ١ جم، كل ١٢ ساعة",
    to: ["الجرعة القادمة ٩:٠٠ م", "المتبقي ٤ أقراص"],
    bg: "#FBE7DE",
    chip: "#D95726",
    mood: "think",
    prop: "pill",
  },
  {
    title: "عائلتك",
    line: "مهام وتحديات للأبناء، ومحادثة واحدة للبيت كله.",
    from: "مهمة: ترتيب الغرفة قبل المغرب",
    to: ["أنجزتها سارة", "+٢٠ نقطة"],
    bg: "#D9F2E6",
    chip: "#0B6B4E",
    mood: "love",
    prop: "heart",
  },
];

const ease = [0.16, 1, 0.3, 1] as const;

// One pinned stage: the page colour, Zado's mood and what Zado holds change
// with each chapter, so the scroll reads as one character living four scenes.
export default function Story() {
  const ref = useRef<HTMLElement>(null);
  const reduce = useReducedMotion();
  const n = chapters.length;
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end end"] });
  const [active, setActive] = useState(0);
  useMotionValueEvent(scrollYProgress, "change", (p) => {
    const next = Math.min(n - 1, Math.max(0, Math.floor(p * n)));
    if (next !== active) setActive(next);
  });
  const bg = useTransform(
    scrollYProgress,
    chapters.map((_, i) => i / (n - 1)),
    chapters.map((c) => c.bg),
  );
  const bar = useTransform(scrollYProgress, [0, 1], [0, 1]);
  const c = chapters[active];

  return (
    <section id="story" ref={ref} className="relative" style={{ height: `${n * 100}dvh` }}>
      <motion.div style={{ backgroundColor: bg }} className="sticky top-0 flex h-[100dvh] flex-col overflow-hidden">
        <div className="mx-auto grid w-full max-w-[1300px] flex-1 grid-cols-1 items-center gap-2 px-4 pt-20 md:grid-cols-2 md:gap-10 md:px-10">
          {/* Copy */}
          <div className="order-2 md:order-1">
            {/* Keyed enter only: no exit to wait on, so a fast scroll never shows a gap. */}
              <motion.div
                key={active}
                initial={reduce ? false : { opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.45, ease }}
              >
                <h3 className="display text-7xl leading-[0.95] text-emerald md:text-[9rem]">{c.title}</h3>
                <p className="mt-4 max-w-[30ch] text-lg leading-relaxed text-slate md:mt-6 md:text-2xl">{c.line}</p>

                <div className="mt-6 max-w-[460px] rounded-3xl border border-hairline bg-white/80 p-5 shadow-card md:mt-8">
                  <p className="rounded-2xl bg-canvas-2 p-3 text-sm leading-relaxed text-muted md:text-base">{c.from}</p>
                  <div className="mt-4 flex flex-wrap gap-2">
                    {c.to.map((t, i) => (
                      <motion.span
                        key={t}
                        initial={reduce ? false : { opacity: 0, scale: 0.6 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{ type: "spring", stiffness: 300, damping: 18, delay: 0.25 + i * 0.1 }}
                        className="rounded-full px-4 py-2 text-sm font-bold md:text-base"
                        style={i === 0 ? { background: c.chip, color: "#fff" } : { background: "#EDEFE9", color: "#1F1F14" }}
                      >
                        {t}
                      </motion.span>
                    ))}
                  </div>
                </div>
              </motion.div>
          </div>

          {/* Zado */}
          <div className="order-1 flex items-end justify-center md:order-2">
            <motion.div
              key={active}
              initial={reduce ? false : { scale: 0.85, rotate: -6 }}
              animate={{ scale: 1, rotate: 0 }}
              transition={{ type: "spring", stiffness: 200, damping: 12 }}
              className="h-[26vh] md:h-[52vh]"
            >
              <Zado mood={c.mood} prop={c.prop} className="aspect-[240/264] h-full" />
            </motion.div>
          </div>
        </div>

        <div className="mx-auto mb-8 h-[3px] w-full max-w-[280px] overflow-hidden rounded-full bg-black/10">
          <motion.div style={{ scaleX: bar }} className="h-full origin-right bg-emerald" />
        </div>
      </motion.div>
    </section>
  );
}
