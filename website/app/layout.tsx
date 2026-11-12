import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";

const cairo = localFont({
  src: "../public/fonts/cairo_variable.ttf",
  variable: "--font-cairo",
  weight: "200 1000",
  display: "swap",
});

export const metadata: Metadata = {
  title: "زاد | عقل واحد لبيتك كله",
  description:
    "زاد بيقرا مصاريفك من رسايل البنك، بيعرف ناقص إيه في المطبخ، وبيفكّرك بالدوا. لعيلتك كلها. من أسترا لاب.",
  applicationName: "Zad",
  authors: [{ name: "Astra Lab" }],
  icons: { icon: "/carrot_logo.svg" },
  openGraph: {
    title: "زاد | عقل واحد لبيتك كله",
    description: "مصاريفك، مطبخك، دواك وعيلتك في تطبيق واحد بيفكر معاك.",
    locale: "ar_EG",
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: "#070d0a",
  colorScheme: "dark",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl" className={`${cairo.variable} antialiased`}>
      <body className="grain min-h-[100dvh] overflow-x-clip">{children}</body>
    </html>
  );
}
