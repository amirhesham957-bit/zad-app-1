import type { Metadata, Viewport } from "next";
import { Cairo, Markazi_Text } from "next/font/google";
import "./globals.css";

// Cairo is the app's own face; Markazi Text carries the big editorial lines.
// next/font downloads both at build time and self-hosts them as woff2.
const cairo = Cairo({
  subsets: ["arabic", "latin"],
  variable: "--font-cairo",
  display: "swap",
});

const display = Markazi_Text({
  subsets: ["arabic", "latin"],
  variable: "--font-markazi",
  display: "swap",
});

export const metadata: Metadata = {
  title: "زاد | عقل واحد لبيتك كله",
  description:
    "زاد بيسجّل مصاريفك من رسايل البنك، بيعرف ناقص إيه في المطبخ، وبيفكّرك بالدوا. ومعاه زادو. من أسترا لابس.",
  applicationName: "Zad",
  authors: [{ name: "Astra Labs" }],
  icons: { icon: "/carrot_logo.svg" },
  openGraph: {
    title: "زاد | عقل واحد لبيتك كله",
    description: "مصاريفك، مطبخك، دواك وعيلتك في تطبيق واحد بيفكر معاك.",
    locale: "ar_EG",
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: "#f8f9fa",
  colorScheme: "light",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl" className={`${cairo.variable} ${display.variable} antialiased`}>
      <body className="min-h-[100dvh] overflow-x-clip">{children}</body>
    </html>
  );
}
