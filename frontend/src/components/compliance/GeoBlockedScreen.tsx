"use client";

import { GeoLocation } from "@/services/geoBlocking";

interface GeoBlockedScreenProps {
  location?: GeoLocation;
  reason?: string;
}

export function GeoBlockedScreen({ location, reason }: GeoBlockedScreenProps) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-b from-zinc-900 to-black p-4">
      <div className="max-w-md rounded-xl border border-red-500/30 bg-zinc-900/80 p-8 text-center">
        <div className="mb-6 flex justify-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-red-500/20">
            <svg
              className="h-8 w-8 text-red-500"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
          </div>
        </div>

        <h1 className="mb-2 text-2xl font-bold text-white">
          Access Restricted
        </h1>

        <p className="mb-6 text-zinc-400">
          {reason || "This service is not available in your region due to regulatory restrictions."}
        </p>

        {location && (
          <div className="mb-6 rounded-lg bg-zinc-800/50 p-4 text-sm">
            <p className="text-zinc-500">
              Detected location:{" "}
              <span className="font-medium text-zinc-300">
                {location.city && `${location.city}, `}
                {location.region && `${location.region}, `}
                {location.country}
              </span>
            </p>
          </div>
        )}

        <div className="space-y-4 text-sm text-zinc-500">
          <p>
            Paimon Gold Protocol is not available to residents or citizens of the
            United States due to regulatory requirements.
          </p>
          <p>
            If you believe this is an error, please ensure you are not using a VPN
            or proxy that may incorrectly identify your location.
          </p>
        </div>

        <div className="mt-8 border-t border-zinc-800 pt-6">
          <p className="text-xs text-zinc-600">
            For compliance inquiries, contact{" "}
            <a
              href="mailto:compliance@paimongold.io"
              className="text-amber-500 hover:underline"
            >
              compliance@paimongold.io
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}
