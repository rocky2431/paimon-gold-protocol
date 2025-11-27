# Feature: Build Wallet Connection Component

**Task ID**: 16
**Status**: In Progress
**Branch**: feat/task-16-wallet-connect

## Overview

Enhance the existing WalletConnect component to support multiple wallet providers (4+ wallets) including MetaMask, WalletConnect v2, Coinbase Wallet, and Trust Wallet.

## Rationale

The current implementation only uses the `injected()` connector which primarily supports browser extension wallets like MetaMask. To meet the acceptance criteria of "Connect with 4+ wallets", we need to add:
- WalletConnect v2 protocol support (mobile wallets, QR code)
- Coinbase Wallet connector
- Trust Wallet (via WalletConnect + injected)

## Impact Assessment

- **User Stories Affected**: specs/product.md#usability-requirements
- **Architecture Changes**: No - wagmi config extension only
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/product.md#usability-requirements

## Implementation Plan

1. Install additional connector packages (@wagmi/connectors)
2. Update wagmi config with new connectors
3. Enhance WalletConnect UI with wallet icons
4. Test all wallet connections
5. Verify network switching works for all wallets

## Acceptance Criteria

- [x] Display address and balance (existing)
- [x] Switch to BSC if wrong network (existing)
- [ ] Connect with 4+ wallets (MetaMask, WalletConnect, Coinbase, Trust)
