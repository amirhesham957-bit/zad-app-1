"use client";

import { useRef } from "react";
import {
  motion,
  useMotionValue,
  useReducedMotion,
  useScroll,
  useSpring,
  useTransform,
  type MotionValue,
} from "motion/react";
import {
  BellRingingIcon,
  CoinsIcon,
  CookingPotIcon,
  PillIcon,
  ReceiptIcon,
  ShoppingCartSimpleIcon,
  type Icon,
} from "@phosphor-icons/react";
import { StoreButtons } from "./StoreButtons";
import Zado from "./Zado";

const ease = [0.16, 1, 0.3, 1] as const;

type StickerSpec = {
  icon: Icon;
  color: string;
  // Position in % of the stage, rotation, parallax depth, bob seconds.
  x: string;
  y: string;
  r: number;
  depth: number;
  d: number;
  size: number;
  hideOnMobile?: boolean;
};

// The things Zad looks after, floating round Zado like stickers.
const stickers: StickerSpec[] = [
  { icon: CoinsIcon, color: "#C68216", x: "14%", y: "22%", r: -12, depth: 34, d: 4.2, size: 84 },
  { icon: ReceiptIcon, color: "#064E3B", x: "80%", y: "18%", r: 10, depth: 48, d: 5, size: 92 },
  { icon: PillIcon, color: "#D95726", x: "88%", y: "56%", r: -8, depth: 26, d: 3.8, size: 72, hideOnMobile: true },
  { icon: CookingPotIcon, color: "#0F9B76", x: "7%", y: "58%", r: 8, depth: 40, d: 4.6, size: 88, hideOnMobile: true },
  { icon: ShoppingCartSimpleIcon, color: "#0B6B4E", x: "27%", y: "8%", r: 6, depth: 18, d: 5.4, size: 60, hideOnMobile: true },
  { icon: BellRingingIcon, color: "#C68216", x: "70%", y: "70%", r: 14, depth: 20, d: 4.9, size: 58, hideOnMobile: true },
];

function Sticker({
  s,
  i,
  mx,
  my,
  reduce,
}: {
  s: StickerSpec;
  i: number;
  mx: MotionValue<number>;
  my: MotionValue<number>;
  reduce: boolean;
}) {
  const x = useTransform(mx, (v) => v * s.depth);
  const y = useTransform(my, (v) => v * s.depth);
  const IconC = s.icon;
  return (
    <motion.div
      style={{ x, y, left: s.x, top: s.y }}
      initial={reduce ? false : { opacity: 0, scale: 0.3 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ type: "spring", stiffness: 180, damping: 14, delay: 0.5 + i * 0.08 }}
      className={`absolute ${s.hideOnMobile ? "hidden md:block" : ""}`}
    >
      <div
        className="bob flex items-center justify-center rounded-[28%] border-4 border-white bg-white shadow-float"
        style={{ width: s.size, height: s.size, ["--r" as string]: `${s.r}deg`, ["--d" as string]: `${s.d}s` }}
      >
        <IconC weight="fill" size={s.size * 0.52} color={s.color} />
      </div>
    </motion.div>
  );
}

export default function Hero() {
  const ref = useRef<HTMLElement>(null);
  const reduce = useReducedMotion() ?? false;
  const mx = useSpring(useMotionValue(0), { stiffness: 60, damping: 18 });
  const my = useSpring(useMotionValue(0), { stiffness: 60, damping: 18 });
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  const wordY = useTransform(scrollYProgress, [0, 1], ["0%", reduce ? "0%" : "30%"]);
  const zadoScale = useTransform(scrollYProgress, [0, 1], [1, reduce ? 1 : 0.8]);

  const line = (delay: number) => ({
    initial: reduce ? false : { y: "110%" },
    animate: { y: "0%" },
    transition: { duration: 1, delay, ease },
  });

  return (
    <section
      ref={ref}
      onPointerMove={(e) => {
        if (reduce || e.pointerType !== "mouse") return;
        mx.set(e.clientX / window.innerWidth - 0.5);
        my.set(e.clientY / window.innerHeight - 0.5);
      }}
      className="relative isolate flex min-h-[100dvh] flex-col overflow-hidden bg-gradient-to-b from-mint-50 via-canvas to-canvas pt-20"
    >
      {/* The giant word behind Zado */}
      <motion.div
        aria-hidden
        style={{ y: wordY }}
        className="display pointer-events-none absolute inset-x-0 top-[6%] -z-10 text-center text-[58vw] leading-[0.9] text-mint-100 md:top-[-4%] md:text-[38vw]"
      >
        <motion.span
          className="block"
          initial={reduce ? false : { opacity: 0, scale: 1.15 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 1.4, ease }}
        >
          زاد
        </motion.span>
      </motion.div>

      {/* Stage */}
      <div className="relative mx-auto w-full max-w-[1400px] flex-1 px-4 md:px-10">
        <div className="absolute inset-0">
          {stickers.map((s, i) => (
            <Sticker key={i} s={s} i={i} mx={mx} my={my} reduce={reduce} />
          ))}
        </div>
        <motion.div
          style={{ scale: zadoScale }}
          initial={reduce ? false : { y: 120, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ type: "spring", stiffness: 90, damping: 12, delay: 0.15 }}
          className="relative mx-auto flex h-[40vh] items-end justify-center pt-10 md:h-[46vh]"
        >
          <Zado className="aspect-[240/264] h-full" />
        </motion.div>
      </div>

      {/* Copy: headline at the start edge, buttons at the end edge */}
      <div className="relative mx-auto grid w-full max-w-[1400px] grid-cols-1 items-end gap-8 px-4 pb-10 md:grid-cols-[1.3fr_1fr] md:px-10 md:pb-14">
        <div>
          <h1 className="display text-6xl leading-[1.05] text-emerald sm:text-7xl lg:text-[6.5rem]">
            <span className="-mb-3 block overflow-hidden pb-6">
              <motion.span className="block" {...line(0.3)}>
                بيتك كله،
              </motion.span>
            </span>
            <span className="-mb-3 block overflow-hidden pb-6">
              <motion.span className="block" {...line(0.42)}>
                في <em className="not-italic text-mustard">عقل واحد.</em>
              </motion.span>
            </span>
          </h1>
        </div>
        <motion.div
          initial={reduce ? false : { opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.65, ease }}
          className="md:justify-self-end"
        >
          <p className="mb-6 max-w-[34ch] text-lg leading-relaxed text-slate">
            زاد بيسجّل مصاريفك من رسايل البنك، بيعرف ناقص إيه في المطبخ، وبيفكّرك بمعاد الدوا.
          </p>
          <StoreButtons />
        </motion.div>
      </div>
    </section>
  );
}
