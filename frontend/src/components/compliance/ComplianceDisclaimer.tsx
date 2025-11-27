"use client";

import { useState, useCallback, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

interface ComplianceDisclaimerProps {
  isOpen: boolean;
  onAccept: () => void;
  onDecline: () => void;
}

const DISCLAIMER_ACCEPTED_KEY = "paimon_disclaimer_accepted";
const DISCLAIMER_VERSION = "1.0"; // Increment when terms change

/**
 * Check if user has previously accepted the disclaimer
 */
export function hasAcceptedDisclaimer(): boolean {
  if (typeof window === "undefined") return false;

  try {
    const accepted = localStorage.getItem(DISCLAIMER_ACCEPTED_KEY);
    if (!accepted) return false;

    const parsed = JSON.parse(accepted);
    return parsed.version === DISCLAIMER_VERSION && parsed.accepted === true;
  } catch {
    return false;
  }
}

/**
 * Save disclaimer acceptance
 */
export function saveDisclaimerAcceptance(): void {
  if (typeof window === "undefined") return;

  try {
    localStorage.setItem(
      DISCLAIMER_ACCEPTED_KEY,
      JSON.stringify({
        accepted: true,
        version: DISCLAIMER_VERSION,
        timestamp: new Date().toISOString(),
      })
    );
  } catch {
    // Ignore storage errors
  }
}

/**
 * Clear disclaimer acceptance (for testing)
 */
export function clearDisclaimerAcceptance(): void {
  if (typeof window === "undefined") return;
  localStorage.removeItem(DISCLAIMER_ACCEPTED_KEY);
}

export function ComplianceDisclaimer({
  isOpen,
  onAccept,
  onDecline,
}: ComplianceDisclaimerProps) {
  const [hasScrolled, setHasScrolled] = useState(false);
  const [checkboxChecked, setCheckboxChecked] = useState(false);

  // Reset state when dialog opens
  useEffect(() => {
    if (isOpen) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setHasScrolled(false);
       
      setCheckboxChecked(false);
    }
  }, [isOpen]);

  const handleScroll = useCallback((e: React.UIEvent<HTMLDivElement>) => {
    const target = e.target as HTMLDivElement;
    const isAtBottom = target.scrollHeight - target.scrollTop <= target.clientHeight + 50;
    if (isAtBottom) {
      setHasScrolled(true);
    }
  }, []);

  const handleAccept = useCallback(() => {
    saveDisclaimerAcceptance();
    onAccept();
  }, [onAccept]);

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onDecline()}>
      <DialogContent className="max-w-2xl bg-zinc-900 border-zinc-800">
        <DialogHeader>
          <DialogTitle className="text-xl font-bold">
            Terms of Use & Risk Disclosure
          </DialogTitle>
          <DialogDescription className="text-zinc-400">
            Please read and acknowledge the following before proceeding
          </DialogDescription>
        </DialogHeader>

        <div
          className="max-h-[400px] overflow-y-auto rounded-lg bg-zinc-800/50 p-4 text-sm"
          onScroll={handleScroll}
        >
          <div className="space-y-4 text-zinc-300">
            <section>
              <h3 className="mb-2 font-semibold text-white">1. Eligibility</h3>
              <p>
                By using this protocol, you confirm that you are NOT a resident or citizen of
                the United States of America, or any jurisdiction where the use of this
                protocol would be prohibited or restricted by law.
              </p>
            </section>

            <section>
              <h3 className="mb-2 font-semibold text-white">2. Risk Disclosure</h3>
              <p>
                Trading leveraged positions involves significant risk. You may lose more than
                your initial investment. Gold prices are volatile and can change rapidly.
                Leverage amplifies both gains and losses.
              </p>
              <ul className="mt-2 list-disc pl-4 space-y-1 text-zinc-400">
                <li>Maximum leverage of 20x means a 5% adverse move can result in 100% loss</li>
                <li>Liquidation occurs when health factor falls below 1.0</li>
                <li>Smart contract risks exist despite security audits</li>
                <li>Oracle failures or manipulation could affect positions</li>
              </ul>
            </section>

            <section>
              <h3 className="mb-2 font-semibold text-white">3. Regulatory Compliance</h3>
              <p>
                This protocol is not registered with any financial regulatory authority.
                It is your responsibility to ensure compliance with local laws and regulations.
                The protocol operators bear no responsibility for users who access the
                platform from restricted jurisdictions.
              </p>
            </section>

            <section>
              <h3 className="mb-2 font-semibold text-white">4. No Financial Advice</h3>
              <p>
                Nothing on this platform constitutes financial, investment, or trading advice.
                You should consult with qualified professionals before making any financial
                decisions. Past performance does not guarantee future results.
              </p>
            </section>

            <section>
              <h3 className="mb-2 font-semibold text-white">5. OFAC Compliance</h3>
              <p>
                By using this protocol, you confirm that you are not on any sanctions list
                maintained by the Office of Foreign Assets Control (OFAC) or any other
                governmental authority. Sanctioned wallet addresses are blocked from
                interacting with this protocol.
              </p>
            </section>

            <section>
              <h3 className="mb-2 font-semibold text-white">6. Limitation of Liability</h3>
              <p>
                The protocol is provided &quot;as is&quot; without warranties of any kind. In no event
                shall the protocol operators be liable for any damages arising from the use
                or inability to use the protocol, including but not limited to direct,
                indirect, incidental, or consequential damages.
              </p>
            </section>

            <div className="mt-4 rounded-lg bg-amber-500/10 p-3 text-amber-400">
              <p className="font-medium">
                By proceeding, you acknowledge that you have read, understood, and agree to
                be bound by these terms. You confirm that you meet the eligibility requirements
                and accept all risks associated with using this protocol.
              </p>
            </div>
          </div>
        </div>

        <div className="mt-4 flex items-start gap-3">
          <input
            type="checkbox"
            id="accept-terms"
            checked={checkboxChecked}
            onChange={(e) => setCheckboxChecked(e.target.checked)}
            disabled={!hasScrolled}
            className="mt-1 h-4 w-4 rounded border-zinc-600 bg-zinc-800 text-amber-500 focus:ring-amber-500 disabled:opacity-50"
          />
          <label
            htmlFor="accept-terms"
            className={`text-sm ${hasScrolled ? "text-zinc-300" : "text-zinc-500"}`}
          >
            I have read and agree to the Terms of Use and Risk Disclosure. I confirm that I
            am not a US resident or citizen, and I am not on any sanctions list.
            {!hasScrolled && (
              <span className="ml-2 text-amber-500">(Please scroll to the bottom to continue)</span>
            )}
          </label>
        </div>

        <DialogFooter className="mt-4 flex gap-3">
          <Button variant="ghost" onClick={onDecline} className="text-zinc-400">
            Decline
          </Button>
          <Button
            onClick={handleAccept}
            disabled={!checkboxChecked}
            className="bg-amber-500 text-black hover:bg-amber-400 disabled:opacity-50"
          >
            Accept & Continue
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
