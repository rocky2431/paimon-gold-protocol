import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Web3Provider } from "@/providers/Web3Provider";
import { ComplianceProvider } from "@/providers/ComplianceProvider";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Paimon Gold Protocol",
  description: "Multi-leverage gold ETF trading on BSC",
  icons: {
    icon: "/favicon.ico",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} font-sans antialiased`}>
        <Web3Provider>
          <ComplianceProvider>{children}</ComplianceProvider>
        </Web3Provider>
      </body>
    </html>
  );
}
