"use client";

import { motion, useReducedMotion } from "motion/react";
import { ChefHatIcon, ShieldCheckIcon, TagIcon, TranslateIcon } from "@phosphor-icons/react";
import Zado from "./Zado";

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
      whileHover={reduce ? undefined : { y: -6 }}
      viewport={{ once: true, amount: 0.25 }}
      transition={{ duration: 0.7, delay, ease }}
      className={`spotlight relative overflow-hidden rounded-[2rem] border border-hairline p-7 shadow-card md:p-9 ${className}`}
    >
      {children}
    </motion.div>
  );
}

const dialects = ["يا هلا", "إيش الأخبار؟", "كيفك يا غالي", "شلونك", "إزيك يا باشا"];

export default function Bento() {
  return (
    <section id="brain" className="mx-auto max-w-[1400px] px-4 pb-28 md:px-10 md:pb-40">
      <h2 className="display max-w-[20ch] text-6xl leading-[1] text-emerald md:text-8xl">
        ليس تطبيق ميزانية. <span className="text-mustard">بل عقلٌ يتذكّر عنك.</span>
      </h2>

      <div className="mt-14 grid grid-cols-1 gap-4 md:grid-cols-6">
        {/* Brain chat: the app's green card */}
        <Cell className="min-h-[440px] bg-gradient-to-br from-green-700 to-emerald-deep text-white md:col-span-4 md:row-span-2">
          <div className="relative flex h-full flex-col">
            <h3 className="display max-w-[14ch] text-5xl leading-[1.05] md:text-6xl">اسأله كما تسأل أحد أفراد بيتك</h3>
            <p className="mt-3 max-w-[40ch] text-white/75">
              يرى عقل زاد مصاريفك ومخزونك ومواعيدك، فيجيبك بأرقامك أنت لا بكلام عام.
            </p>
            <div className="mt-auto space-y-3 pe-0 pt-10 md:pe-44">
              <p className="ms-auto w-fit max-w-[85%] rounded-3xl rounded-bl-md bg-white/12 px-5 py-3">
                كم أقدر أصرف اليوم؟
              </p>
              <p className="w-fit max-w-[85%] rounded-3xl rounded-br-md bg-white px-5 py-3 font-semibold text-emerald">
                ١٨٠ ر.س براحتك. باقي ١١ يوم على الراتب، والإيجار لسّه ما اندفع.
              </p>
            </div>
            <div className="absolute -bottom-4 end-0 hidden h-44 md:block">
              <Zado mood="think" className="aspect-[240/264] h-full" bubbleSide="none" />
            </div>
          </div>
        </Cell>

        {/* Dialect */}
        <Cell className="bg-surface md:col-span-2" delay={0.08}>
          <TranslateIcon size={36} weight="duotone" className="text-green-600" />
          <h3 className="mt-4 text-2xl font-black text-ink">يتحدث بلهجتك</h3>
          <div className="mt-5 flex flex-wrap gap-2">
            {dialects.map((d) => (
              <span key={d} className="rounded-full bg-mint-50 px-3 py-1 text-sm font-semibold text-green-700">
                {d}
              </span>
            ))}
          </div>
        </Cell>

        {/* Chef */}
        <Cell className="bg-[#FBF0D9] md:col-span-2" delay={0.16}>
          <ChefHatIcon size={36} weight="duotone" className="text-mustard" />
          <h3 className="mt-4 text-2xl font-black text-ink">شيف زاد</h3>
          <p className="mt-2 text-slate">وصفة اليوم مما في مطبخك فعلاً.</p>
        </Cell>

        {/* Crowd prices */}
        <Cell className="bg-[#FBE7DE] md:col-span-3" delay={0.08}>
          <TagIcon size={36} weight="duotone" className="text-rust" />
          <h3 className="mt-4 text-2xl font-black text-ink">أسعار حقيقية من حولك</h3>
          <p className="mt-2 max-w-[38ch] text-slate">
            اعرف الأسعار الفعلية في المتاجر القريبة منك، من فواتير الناس أنفسهم.
          </p>
        </Cell>

        {/* Privacy */}
        <Cell className="bg-mint-50 md:col-span-3" delay={0.16}>
          <ShieldCheckIcon size={36} weight="duotone" className="text-green-700" />
          <h3 className="mt-4 text-2xl font-black text-ink">بياناتك لعائلتك فقط</h3>
          <p className="mt-2 max-w-[38ch] text-slate">
            كل سجل في قاعدة البيانات مقصور على عائلتك، ولا نطلب صلاحية قراءة الرسائل.
          </p>
        </Cell>
      </div>
    </section>
  );
}
