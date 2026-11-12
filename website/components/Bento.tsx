"use client";

import { motion, useReducedMotion } from "motion/react";
import {
  ChatCircleDotsIcon,
  ChefHatIcon,
  ShieldCheckIcon,
  TagIcon,
  TranslateIcon,
} from "@phosphor-icons/react";

const ease = [0.16, 1, 0.3, 1] as const;

function track(e: React.PointerEvent<HTMLElement>) {
  const el = e.currentTarget;
  const r = el.getBoundingClientRect();
  el.style.setProperty("--x", `${e.clientX - r.left}px`);
  el.style.setProperty("--y", `${e.clientY - r.top}px`);
}

function Cell({
  className = "",
  delay = 0,
  children,
}: {
  className?: string;
  delay?: number;
  children: React.ReactNode;
}) {
  const reduce = useReducedMotion();
  return (
    <motion.div
      onPointerMove={track}
      initial={reduce ? false : { opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.25 }}
      transition={{ duration: 0.9, delay, ease }}
      className={`spotlight relative overflow-hidden rounded-[2rem] border border-line bg-ink-2 p-7 md:p-9 ${className}`}
    >
      {children}
    </motion.div>
  );
}

const dialects = ["إزيك يا باشا", "هلا والله", "كيفك يا غالي", "شلونك", "لاباس عليك"];

export default function Bento() {
  return (
    <section id="brain" className="mx-auto max-w-[1400px] px-4 py-28 md:px-10 md:py-40">
      <h2 className="max-w-[22ch] text-4xl font-black leading-[1.15] md:text-6xl">
        مش تطبيق ميزانية. <span className="text-carrot">عقل بيفتكر عنك.</span>
      </h2>

      <div className="mt-14 grid grid-cols-1 gap-4 md:grid-cols-6 md:grid-rows-[auto_auto_auto]">
        {/* Brain chat: the hero cell */}
        <Cell className="md:col-span-4 md:row-span-2 min-h-[420px]">
          <div aria-hidden className="orb absolute -left-24 -top-24 h-80 w-80 rounded-full opacity-60" />
          <div className="relative flex h-full flex-col">
            <ChatCircleDotsIcon size={40} weight="duotone" className="text-carrot" />
            <h3 className="mt-5 text-3xl font-black md:text-4xl">اسأله زي ما تسأل حد من البيت</h3>
            <p className="mt-3 max-w-[40ch] text-mist">
              عقل زاد شايف مصاريفك ومخزنك ومواعيدك، فبيرد عليك بأرقامك انت مش بكلام عام.
            </p>
            <div className="mt-auto space-y-3 pt-10">
              <p className="ms-auto w-fit max-w-[85%] rounded-3xl rounded-bl-md bg-bone/10 px-5 py-3 text-bone">
                أقدر أصرف قد إيه النهارده؟
              </p>
              <p className="w-fit max-w-[85%] rounded-3xl rounded-br-md bg-carrot px-5 py-3 font-semibold text-ink">
                ١٨٠ ج.م بالراحة. فاضل ١١ يوم على المرتب والإيجار لسه ماتدفعش.
              </p>
            </div>
          </div>
        </Cell>

        {/* Dialect */}
        <Cell className="md:col-span-2" delay={0.08}>
          <TranslateIcon size={34} weight="duotone" className="text-carrot" />
          <h3 className="mt-4 text-2xl font-black">بيتكلم بلهجتك</h3>
          <div className="mt-5 flex flex-wrap gap-2">
            {dialects.map((d) => (
              <span key={d} className="rounded-full border border-line px-3 py-1 text-sm text-mist">
                {d}
              </span>
            ))}
          </div>
        </Cell>

        {/* Chef */}
        <Cell className="md:col-span-2 bg-gradient-to-br from-leaf/25 via-ink-2 to-ink-2" delay={0.16}>
          <ChefHatIcon size={34} weight="duotone" className="text-carrot" />
          <h3 className="mt-4 text-2xl font-black">شيف زاد</h3>
          <p className="mt-2 text-mist">وصفة النهارده من اللي عندك في المطبخ فعلاً.</p>
        </Cell>

        {/* Crowd prices */}
        <Cell className="md:col-span-3 bg-gradient-to-tl from-carrot/20 via-ink-2 to-ink-2" delay={0.08}>
          <TagIcon size={34} weight="duotone" className="text-carrot" />
          <h3 className="mt-4 text-2xl font-black">أسعار من الناس اللي حواليك</h3>
          <p className="mt-2 max-w-[38ch] text-mist">
            اعرف السعر الحقيقي في المحلات اللي جنبك، من فواتير الناس نفسها.
          </p>
        </Cell>

        {/* Privacy */}
        <Cell className="md:col-span-3" delay={0.16}>
          <ShieldCheckIcon size={34} weight="duotone" className="text-carrot" />
          <h3 className="mt-4 text-2xl font-black">بياناتك لعيلتك بس</h3>
          <p className="mt-2 max-w-[38ch] text-mist">
            كل صف في قاعدة البيانات مقفول على عيلتك. ومش محتاجين صلاحية قراية الرسايل.
          </p>
        </Cell>
      </div>
    </section>
  );
}
