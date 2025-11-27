# Project Constitution - Paimon Gold Protocol

This document defines the core principles and standards for this project. It serves as the foundation for all development decisions.

> **Configuration Values**: All numeric thresholds and limits (e.g., max function lines, test coverage %, Core Web Vitals targets) are defined in `.ultra/config.json`. This document provides the **qualitative principles** only.

## Development Principles

### 1. Specification-Driven
- Specifications are the source of truth
- Code derives from specs, not vice versa
- Changes require spec updates first

### 2. Test-First Development
- Write tests before implementation
- Coverage targets defined in config.json (overall, critical paths, branch)
- Integration tests with real services (forked mainnet for DeFi)

### 3. Minimal Abstraction
- Use frameworks directly, avoid unnecessary wrappers
- Abstraction only when pattern repeats >=3 times
- Favor composition over inheritance

### 4. Anti-Future-Proofing
- Build only for current requirements
- No speculative features
- Refactor when new requirements emerge

### 5. Library-First
- Extract reusable logic to libraries
- Libraries before applications
- Internal packages for shared code

### 6. Simplicity
- Maximum 3 projects for initial features
- Complexity and function size limits defined in config.json
- Favor readability over cleverness

### 7. Single Source of Truth
- One canonical representation per concept
- Specs in `.ultra/specs/`
- Decisions in ADRs

### 8. Explicit Decisions
- All architecture decisions documented
- Rationale traces to requirements
- Trade-offs acknowledged

### 9. Living Documentation
- Documentation evolves with code
- Monthly ADR review
- Specs updated with every feature

## Quality Standards

### Code Quality
- SOLID principles enforced (see config.json for thresholds)
- DRY: No duplication (max duplicate lines in config.json)
- KISS: Low complexity (max complexity in config.json)
- YAGNI: Only current requirements
- Function size and nesting limits defined in config.json

### Testing
- Test coverage targets defined in config.json (overall, critical paths, branch, function)
- Six-dimensional coverage required:
  1. Functional (core logic)
  2. Boundary (edge cases)
  3. Exception (error handling)
  4. Performance (load tests)
  5. Security (injection prevention)
  6. Compatibility (cross-platform)

### Smart Contract Specific
- Reentrancy guards on all external calls
- Access control on privileged functions
- Oracle freshness and manipulation checks
- Gas optimization (target defined in config.json)
- Formal verification for critical math

### Frontend (if applicable)
- Avoid default fonts (Inter/Roboto/Open Sans)
- Use design tokens/CSS variables
- Prefer established UI libraries
- Core Web Vitals targets defined in config.json (LCP, INP, CLS)

## Technology Constraints

**Blockchain**:
- Must deploy on BSC (BNB Chain)
- Solidity ^0.8.x (latest stable)
- OpenZeppelin Contracts v5.x
- Chainlink price feeds for XAU/USD

**Frontend**:
- TypeScript required (no plain JS)
- React/Next.js for UI
- wagmi + viem for Web3 integration

**Security**:
- Pre-launch audit mandatory
- Bug bounty program required
- Multi-sig for admin operations

## Git Workflow

- Branch naming: `feat/task-{id}-{description}`, `fix/bug-{id}-{description}`
- Commit format: Conventional Commits
- Independent branches: Each task gets its own branch
- Immediate merge: Merge to main after task completion

## Architecture Decision Process

All significant technical decisions must:
1. Be documented as ADRs in `.ultra/docs/decisions/`
2. Include context, decision, rationale, consequences
3. Be reviewed and approved
4. Link back to requirements in specs

## Customization

This template provides baseline principles. Customize the following sections for your project:

- **Technology Constraints**: Add your specific stack requirements
- **Performance Targets**: Define your specific metrics
- **Security Requirements**: Add compliance needs (audit firms, bug bounty)
- **Custom Principles**: Add project-specific rules

---

Last Updated: 2025-11-27
