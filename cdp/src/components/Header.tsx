"use client";
import { useEvmAddress } from "@coinbase/cdp-hooks";
import { AuthButton } from "@coinbase/cdp-react/components/AuthButton";
import { useEffect, useState } from "react";

import { IconCheck, IconCopy, IconUser } from "@/components/Icons";

/**
 * Header component
 */
interface HeaderProps {
  title?: string;
  subtitle?: string;
  showNetworkBadge?: boolean;
}

export default function Header(props: HeaderProps) {
  const { title, subtitle, showNetworkBadge } = props;
  const { evmAddress } = useEvmAddress();
  const [isCopied, setIsCopied] = useState(false);

  const copyAddress = async () => {
    if (!evmAddress) return;
    try {
      await navigator.clipboard.writeText(evmAddress);
      setIsCopied(true);
    } catch (error) {
      console.error(error);
    }
  };

  useEffect(() => {
    if (!isCopied) return;
    const timeout = setTimeout(() => {
      setIsCopied(false);
    }, 2000);
    return () => clearTimeout(timeout);
  }, [isCopied]);

  return (
    <header className="sticky top-0 z-30 w-full border-b border-gray-200 bg-white/70 backdrop-blur">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3">
        <div className="flex min-w-0 flex-col gap-1">
          
          {title && (
            <div className="flex flex-wrap items-center gap-3">
              <h2 className="truncate text-xl font-bold text-gray-900">{title}</h2>
              {subtitle && <p className="truncate text-sm text-gray-600">{subtitle}</p>}
              {showNetworkBadge && (
                <span className="hidden items-center gap-1 rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-medium text-emerald-700 ring-1 ring-emerald-200 sm:inline-flex">
                  <span className="h-2 w-2 rounded-full bg-emerald-500" />
                  Base Network
                </span>
              )}
            </div>
          )}
        </div>
        <div className="flex items-center gap-3">
          {evmAddress && (
            <button
              aria-label="copy wallet address"
              className="inline-flex items-center rounded-lg border border-gray-300 bg-white px-2.5 py-1.5 text-sm text-gray-700 shadow-sm hover:bg-gray-50"
              onClick={copyAddress}
            >
              {!isCopied && (
                <>
                  <IconUser className="mr-1 h-4 w-4" />
                  <IconCopy className="mr-1 h-4 w-4" />
                </>
              )}
              {isCopied && <IconCheck className="mr-1 h-4 w-4" />}
              <span className="font-mono">
                {evmAddress.slice(0, 6)}...{evmAddress.slice(-4)}
              </span>
            </button>
          )}
          <div className="[&>button]:rounded-lg [&>button]:bg-primary [&>button]:text-white [&>button]:px-3 [&>button]:py-1.5 [&>button]:text-sm" aria-hidden>
            <AuthButton />
          </div>
        </div>
      </div>
    </header>
  );
}
