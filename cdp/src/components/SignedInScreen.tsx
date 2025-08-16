"use client";

import Header from "@/components/Header";
import PortfolioRebalancer from "@/components/PortfolioRebalancer";

export default function SignedInScreen() {
  return (
    <>
      <Header
        title="Portfolio Rebalancer"
        subtitle="Makes investing easy"
        showNetworkBadge
      />
      <main className="main flex-col-container flex-grow">
        <div className="main-inner flex-col-container">
          <div className="w-full">
            <PortfolioRebalancer />
          </div>
        </div>
      </main>
    </>
  );
}
