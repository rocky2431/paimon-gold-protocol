# Task 21: Create The Graph subgraph for indexing

## Task Details

- **ID**: 21
- **Priority**: P1
- **Complexity**: 5/10
- **Estimated Days**: 2
- **Dependencies**: Task 12 (completed)

## Description

Create subgraph with schema for Position, Trade, LP events. Write event handlers for PositionOpened, PositionClosed, Liquidated, LiquidityAdded, LiquidityRemoved. Deploy to The Graph hosted service or decentralized network.

## Acceptance Criteria

1. [ ] Schema matches spec
2. [ ] Events indexed correctly
3. [ ] GraphQL queries work
4. [ ] Indexing delay <30s

## Implementation Checklist

- [ ] Create subgraph directory structure
- [ ] Define schema.graphql entities
- [ ] Configure subgraph.yaml with contract addresses
- [ ] Write AssemblyScript event handlers
- [ ] Add package.json with graph-cli
- [ ] Generate types from ABI
- [ ] Test locally with graph-node
- [ ] Deploy to hosted service

## Status

- Started: 2025-11-28
- Status: In Progress
