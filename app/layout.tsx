import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://rumar.pt"),
  title: "RUMAR — O teu dia técnico, sob controlo",
  description:
    "O sistema para eletricistas, canalizadores e equipas técnicas: agenda, trabalhos, clientes, materiais e percursos num só lugar.",
  openGraph: {
    title: "RUMAR — O teu dia técnico, sob controlo",
    description:
      "Agenda, trabalhos e clientes num só lugar para equipas técnicas portuguesas.",
    type: "website",
    images: [
      {
        url: "/og.png",
        width: 1200,
        height: 630,
        alt: "RUMAR — sistema para equipas técnicas",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "RUMAR — O teu dia técnico, sob controlo",
    description:
      "Agenda, trabalhos e clientes num só lugar para equipas técnicas portuguesas.",
    images: ["/og.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
