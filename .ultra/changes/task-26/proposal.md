# Feature: Implement geo-blocking for US users

**Task ID**: 26
**Status**: In Progress
**Branch**: feat/task-26-geo-blocking

## Overview

Add IP-based geo-blocking for US users in frontend for regulatory compliance. Display compliance disclaimer before wallet connection and integrate OFAC wallet blacklist check.

## Rationale

US residents are restricted from using leveraged trading platforms without proper regulatory approval. Geo-blocking protects the protocol from regulatory risk while providing clear messaging to affected users.

## Impact Assessment

- **User Stories Affected**: US-5.1 (Compliance check before trading)
- **Architecture Changes**: No
- **Breaking Changes**: No

## Requirements Trace

- Traces to: specs/product.md#regulatory-constraints

## Implementation

### Components

1. **GeoBlockingService** - IP-based location detection via free API
2. **OFACCheckService** - Wallet address blacklist verification
3. **ComplianceDisclaimer** - Modal component for compliance acknowledgment
4. **Enhanced WalletConnect** - Integration with compliance checks

### Technical Approach

- Use free IP geolocation API (ipapi.co or ip-api.com)
- OFAC list from Chainalysis or local JSON file
- Block before wallet connection attempt
- Store disclaimer acknowledgment in localStorage
