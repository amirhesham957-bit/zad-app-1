"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useAnimate, useMotionValue, useReducedMotion, useSpring } from "motion/react";

/*
 * زادو, the app's companion, redrawn for the web from the app's own painter
 * (zad_flutter/lib/shared/orb/presentation/plush_painting.dart + companion_orb.dart):
 * a mochi body that sits, lit from the top-left, glossy toy eyes with two
 * catch-lights, blush, and the two-leaf sprout. Same colours as the catalog
 * (0xFF37C98E over 0xFF0B6B4E), same breath (0.98 to 1.05) and random blinks.
 * Pure SVG + CSS: no canvas, no WebGL.
 */

export type ZadoMood = "idle" | "happy" | "love" | "sleepy" | "think";
export type ZadoProp = "none" | "coin" | "chef" | "pill" | "heart";

const lines = [
  "أهلاً! أنا زادو.",
  "هيهي، بتزغزغني!",
  "معاك في أي حاجة تخص البيت.",
  "حمّلني وخلّيني أشيل عنك.",
  "اللبن قرب يخلص على فكرة.",
];

export default function Zado({
  mood = "idle",
  prop = "none",
  className = "",
  interactive = true,
  bubbleSide = "top",
}: {
  mood?: ZadoMood;
  prop?: ZadoProp;
  className?: string;
  interactive?: boolean;
  bubbleSide?: "top" | "none";
}) {
  const reduce = useReducedMotion();
  const wrap = useRef<HTMLDivElement>(null);
  const [scope, animate] = useAnimate<SVGGElement>();
  const lookX = useSpring(useMotionValue(0), { stiffness: 140, damping: 16 });
  const lookY = useSpring(useMotionValue(0), { stiffness: 140, damping: 16 });
  const [line, setLine] = useState<string | null>(null);
  const [cheer, setCheer] = useState(false);
  const taps = useRef(0);

  // Eyes follow the pointer. Motion values only: no re-render per move.
  useEffect(() => {
    if (reduce || !interactive) return;
    const onMove = (e: PointerEvent) => {
      const el = wrap.current;
      if (!el) return;
      const r = el.getBoundingClientRect();
      const dx = e.clientX - (r.left + r.width / 2);
      const dy = e.clientY - (r.top + r.height / 2);
      const d = Math.hypot(dx, dy) || 1;
      const reach = Math.min(1, d / 320);
      lookX.set((dx / d) * 6 * reach);
      lookY.set((dy / d) * 5 * reach);
    };
    window.addEventListener("pointermove", onMove, { passive: true });
    return () => window.removeEventListener("pointermove", onMove);
  }, [reduce, interactive, lookX, lookY]);

  useEffect(() => {
    if (!line) return;
    const t = setTimeout(() => {
      setLine(null);
      setCheer(false);
    }, 2400);
    return () => clearTimeout(t);
  }, [line]);

  const tap = () => {
    if (!interactive) return;
    setLine(lines[taps.current++ % lines.length]);
    setCheer(true);
    if (reduce) return;
    // The app's hop: up and back with a small stretch.
    animate(
      scope.current,
      { y: [0, -34, 0, -10, 0], scaleY: [1, 1.08, 0.9, 1.03, 1], scaleX: [1, 0.95, 1.08, 0.98, 1] },
      { duration: 0.75, ease: [0.3, 0.7, 0.4, 1] },
    );
  };

  const shown: ZadoMood = cheer ? "happy" : mood;
  const happy = shown === "happy" || shown === "love";
  const hasHat = prop === "chef";

  return (
    <div ref={wrap} className={`relative select-none ${className}`}>
      {bubbleSide === "top" && (
        <motion.div
          initial={false}
          animate={line ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 10, scale: 0.9 }}
          transition={{ type: "spring", stiffness: 300, damping: 22 }}
          aria-live="polite"
          className="pointer-events-none absolute -top-2 left-1/2 z-10 w-max max-w-[240px] -translate-x-1/2 -translate-y-full rounded-2xl bg-white px-4 py-2 text-center text-sm font-bold text-emerald shadow-card"
        >
          {line ?? " "}
        </motion.div>
      )}

      <svg
        viewBox="0 0 240 264"
        role="img"
        aria-label="زادو، رفيق زاد"
        onClick={tap}
        className={`h-full w-full overflow-visible ${interactive ? "cursor-pointer" : ""}`}
      >
        <defs>
          <radialGradient id="zado-body" cx="36%" cy="28%" r="80%">
            <stop offset="0%" stopColor="#8BF0C4" />
            <stop offset="38%" stopColor="#37C98E" />
            <stop offset="78%" stopColor="#1C9A6E" />
            <stop offset="100%" stopColor="#0B6B4E" />
          </radialGradient>
          <radialGradient id="zado-limb" cx="40%" cy="30%" r="75%">
            <stop offset="0%" stopColor="#6FE3B1" />
            <stop offset="100%" stopColor="#1C9A6E" />
          </radialGradient>
          <radialGradient id="zado-coin" cx="35%" cy="30%" r="75%">
            <stop offset="0%" stopColor="#FFE08A" />
            <stop offset="100%" stopColor="#C68216" />
          </radialGradient>
          <filter id="zado-soft" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="7" />
          </filter>
        </defs>

        {/* The shadow it sits on */}
        <ellipse cx="120" cy="246" rx="62" ry="9" fill="#064E3B" opacity="0.14" className="zado-shadow" />

        <g ref={scope} style={{ transformBox: "fill-box", transformOrigin: "50% 100%" }}>
          <g className="zado-breathe">
            {/* Feet */}
            <ellipse cx="86" cy="230" rx="20" ry="11" fill="url(#zado-limb)" />
            <ellipse cx="154" cy="230" rx="20" ry="11" fill="url(#zado-limb)" />

            {/* Body: round crown, widest below the middle, flattened base */}
            <path
              d="M120,66 C170,66 206,104 206,158 C206,206 172,230 120,230 C68,230 34,206 34,158 C34,104 70,66 120,66 Z"
              fill="url(#zado-body)"
              stroke="#0B6B4E"
              strokeOpacity="0.35"
              strokeWidth="1.5"
            />
            {/* Warm bounce under the chin + blurred highlight */}
            <ellipse cx="120" cy="214" rx="46" ry="10" fill="#FFE9A8" opacity="0.18" filter="url(#zado-soft)" />
            <ellipse cx="88" cy="102" rx="30" ry="15" fill="#fff" opacity="0.42" filter="url(#zado-soft)" transform="rotate(-24 88 102)" />

            {/* Hands */}
            <g className={happy ? "zado-wave" : "zado-sway-hand"}>
              <ellipse cx="38" cy="170" rx="13" ry="17" fill="url(#zado-limb)" transform="rotate(18 38 170)" />
            </g>
            <g className={happy ? "zado-wave zado-wave-r" : "zado-sway-hand"}>
              <ellipse cx="202" cy="170" rx="13" ry="17" fill="url(#zado-limb)" transform="rotate(-18 202 170)" />
              {prop === "coin" && (
                <g>
                  <circle cx="212" cy="150" r="17" fill="url(#zado-coin)" stroke="#9A6410" strokeWidth="1.5" />
                  <circle cx="212" cy="150" r="11" fill="none" stroke="#FFF1C7" strokeWidth="1.5" opacity="0.8" />
                </g>
              )}
              {prop === "pill" && (
                <g transform="rotate(-28 212 148)">
                  <rect x="196" y="139" width="34" height="18" rx="9" fill="#FBFAF8" stroke="#D8D2C8" strokeWidth="1" />
                  <path d="M213,139 h8 a9,9 0 0 1 0,18 h-8 z" fill="#D95726" />
                </g>
              )}
              {prop === "heart" && (
                <path
                  className="zado-pulse"
                  d="M212,160 C196,148 198,132 208,132 C212,132 214,135 215,137 C216,135 218,132 222,132 C232,132 234,148 218,160 L215,162 Z"
                  fill="#FF6FA5"
                />
              )}
            </g>

            {/* Blush */}
            <ellipse cx="74" cy="172" rx="12" ry="6.5" fill="#FF9DB2" opacity="0.8" />
            <ellipse cx="166" cy="172" rx="12" ry="6.5" fill="#FF9DB2" opacity="0.8" />

            {/* Eyes */}
            <motion.g style={{ x: lookX, y: lookY }}>
              {happy ? (
                <g fill="none" stroke="#14181F" strokeWidth="5" strokeLinecap="round">
                  <path d="M83,154 Q94,138 105,154" />
                  <path d="M135,154 Q146,138 157,154" />
                </g>
              ) : shown === "sleepy" ? (
                <g fill="none" stroke="#14181F" strokeWidth="4.5" strokeLinecap="round">
                  <path d="M84,150 Q94,158 104,150" />
                  <path d="M136,150 Q146,158 156,150" />
                </g>
              ) : (
                <g className="zado-blink">
                  <ellipse cx="94" cy="150" rx="9.5" ry="12.5" fill="#14181F" />
                  <ellipse cx="146" cy="150" rx="9.5" ry="12.5" fill="#14181F" />
                  <circle cx="97.5" cy="145" r="3.4" fill="#fff" />
                  <circle cx="149.5" cy="145" r="3.4" fill="#fff" />
                  <circle cx="90.5" cy="155" r="1.7" fill="#fff" opacity="0.8" />
                  <circle cx="142.5" cy="155" r="1.7" fill="#fff" opacity="0.8" />
                </g>
              )}
            </motion.g>

            {/* Mouth */}
            {happy ? (
              <path d="M108,170 Q120,190 132,170 Z" fill="#7A1F2B" stroke="#14181F" strokeWidth="2.5" strokeLinejoin="round" />
            ) : shown === "think" ? (
              <ellipse cx="124" cy="176" rx="4.5" ry="4" fill="#14181F" />
            ) : (
              <path d="M111,172 Q120,181 129,172" fill="none" stroke="#14181F" strokeWidth="3.5" strokeLinecap="round" />
            )}

            {/* Crest: the sprout, or the chef's hat in the kitchen */}
            {hasHat ? (
              <g>
                <path
                  d="M84,74 C66,70 62,44 82,40 C84,22 110,18 120,32 C130,18 156,22 158,40 C178,44 174,70 156,74 Z"
                  fill="#FFFFFF"
                  stroke="#E3DED4"
                  strokeWidth="1.5"
                />
                <rect x="84" y="68" width="72" height="16" rx="6" fill="#FBFAF8" stroke="#E3DED4" strokeWidth="1.5" />
              </g>
            ) : (
              <g className="zado-sprout">
                <line x1="120" y1="68" x2="120" y2="50" stroke="#2E8B4A" strokeWidth="5" strokeLinecap="round" />
                <ellipse cx="106" cy="46" rx="15" ry="6.5" fill="#45BF68" transform="rotate(26 106 46)" />
                <ellipse cx="134" cy="46" rx="15" ry="6.5" fill="#45BF68" transform="rotate(-26 134 46)" />
              </g>
            )}
          </g>
        </g>

        {/* What floats outside the squash */}
        {shown === "sleepy" && (
          <g fill="#8FA2FF" fontWeight="800" fontFamily="sans-serif">
            <text x="176" y="84" fontSize="20" className="zado-z">z</text>
            <text x="192" y="62" fontSize="26" className="zado-z zado-z2">z</text>
          </g>
        )}
        {shown === "love" && (
          <g fill="#FF6FA5">
            <path className="zado-float-heart" d="M40,80 c-8,-6 -7,-14 -2,-14 c2,0 3,1.5 3.500,2.500 c0.500,-1 1.500,-2.500 3.500,-2.500 c5,0 6,8 -2,14 l-1.500,1 z" />
            <path className="zado-float-heart zado-fh2" d="M200,64 c-8,-6 -7,-14 -2,-14 c2,0 3,1.5 3.500,2.500 c0.500,-1 1.500,-2.500 3.500,-2.500 c5,0 6,8 -2,14 l-1.500,1 z" />
          </g>
        )}
      </svg>
    </div>
  );
}
