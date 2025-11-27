"use client";

import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from "react";
import { checkGeoBlocking, GeoBlockResult, GeoLocation } from "@/services/geoBlocking";
import { checkOFACBlacklist, OFACCheckResult } from "@/services/ofacCheck";
import {
  ComplianceDisclaimer,
  GeoBlockedScreen,
  hasAcceptedDisclaimer,
} from "@/components/compliance";

interface ComplianceState {
  isLoading: boolean;
  isGeoBlocked: boolean;
  geoBlockResult?: GeoBlockResult;
  hasAcceptedTerms: boolean;
  isOFACBlocked: boolean;
  ofacResult?: OFACCheckResult;
}

interface ComplianceContextType extends ComplianceState {
  checkWalletCompliance: (address: string) => Promise<OFACCheckResult>;
  showDisclaimer: () => void;
  isCompliant: boolean;
}

const ComplianceContext = createContext<ComplianceContextType | null>(null);

export function useCompliance() {
  const context = useContext(ComplianceContext);
  if (!context) {
    throw new Error("useCompliance must be used within ComplianceProvider");
  }
  return context;
}

interface ComplianceProviderProps {
  children: ReactNode;
}

export function ComplianceProvider({ children }: ComplianceProviderProps) {
  const [state, setState] = useState<ComplianceState>({
    isLoading: true,
    isGeoBlocked: false,
    hasAcceptedTerms: false,
    isOFACBlocked: false,
  });

  const [showDisclaimerDialog, setShowDisclaimerDialog] = useState(false);

  // Check geo-blocking and terms acceptance on mount
  useEffect(() => {
    async function checkCompliance() {
      // Check if user has already accepted terms
      const hasAccepted = hasAcceptedDisclaimer();

      // Check geo-blocking
      const geoResult = await checkGeoBlocking();

      setState((prev) => ({
        ...prev,
        isLoading: false,
        isGeoBlocked: geoResult.isBlocked,
        geoBlockResult: geoResult,
        hasAcceptedTerms: hasAccepted,
      }));

      // Show disclaimer if not geo-blocked and hasn't accepted terms
      if (!geoResult.isBlocked && !hasAccepted) {
        setShowDisclaimerDialog(true);
      }
    }

    checkCompliance();
  }, []);

  // Check wallet address against OFAC list
  const checkWalletCompliance = useCallback(async (address: string): Promise<OFACCheckResult> => {
    const result = checkOFACBlacklist(address);

    setState((prev) => ({
      ...prev,
      isOFACBlocked: result.isBlacklisted,
      ofacResult: result,
    }));

    return result;
  }, []);

  // Handle disclaimer acceptance
  const handleDisclaimerAccept = useCallback(() => {
    setState((prev) => ({
      ...prev,
      hasAcceptedTerms: true,
    }));
    setShowDisclaimerDialog(false);
  }, []);

  // Handle disclaimer decline
  const handleDisclaimerDecline = useCallback(() => {
    // Keep dialog open - user must accept to proceed
    // Optionally, could redirect to external site
  }, []);

  // Show disclaimer manually
  const showDisclaimer = useCallback(() => {
    setShowDisclaimerDialog(true);
  }, []);

  // Calculate if user is compliant
  const isCompliant = !state.isGeoBlocked && state.hasAcceptedTerms && !state.isOFACBlocked;

  const contextValue: ComplianceContextType = {
    ...state,
    checkWalletCompliance,
    showDisclaimer,
    isCompliant,
  };

  // Show loading state
  if (state.isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-b from-zinc-900 to-black">
        <div className="text-center">
          <div className="mb-4 h-8 w-8 animate-spin rounded-full border-2 border-amber-500 border-t-transparent mx-auto" />
          <p className="text-zinc-500">Checking compliance...</p>
        </div>
      </div>
    );
  }

  // Show geo-blocked screen
  if (state.isGeoBlocked) {
    return (
      <GeoBlockedScreen
        location={state.geoBlockResult?.location}
        reason={state.geoBlockResult?.reason}
      />
    );
  }

  return (
    <ComplianceContext.Provider value={contextValue}>
      {children}
      <ComplianceDisclaimer
        isOpen={showDisclaimerDialog}
        onAccept={handleDisclaimerAccept}
        onDecline={handleDisclaimerDecline}
      />
    </ComplianceContext.Provider>
  );
}
