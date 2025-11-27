# Feature: Initialize Next.js 14 Frontend with wagmi

**Task ID**: 2
**Status**: In Progress
**Branch**: feat/task-2-nextjs-wagmi

## Overview
Setup the frontend application using Next.js 14 App Router with wagmi v2 for Web3 interactions. This establishes the foundation for all user-facing trading interfaces.

## Rationale
- Next.js 14 provides optimal performance with App Router and Server Components
- wagmi v2 + viem is the industry-standard for React Web3 development
- TanStack Query enables efficient data fetching and caching
- shadcn/ui provides accessible, customizable components

## Impact Assessment
- **User Stories Affected**: All frontend user stories (US-1.x through US-4.x)
- **Architecture Changes**: Yes - establishes frontend directory structure
- **Breaking Changes**: No - new feature

## Technical Decisions
- **Directory**: `frontend/` in project root (monorepo structure)
- **Package Manager**: pnpm (faster, efficient disk space)
- **Styling**: Tailwind CSS + shadcn/ui
- **Chain Config**: BSC mainnet (56) + testnet (97)

## Requirements Trace
- Traces to: specs/architecture.md#frontend-stack
- Traces to: specs/product.md#usability-requirements
