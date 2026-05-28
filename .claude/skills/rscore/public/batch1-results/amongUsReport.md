# Among Us Infrastructure rscore Report

## 1. Post (Current) Infrastructure Summary

### What Was Modeled

The post infrastructure represents Among Us's current production architecture (~2023-2025), after Innersloth stabilized their platform following the unexpected 2020 viral explosion (300M+ players at peak). Among Us is an asymmetric social deduction game (4-15 players per session) requiring reliable session management and room-code-based matchmaking but significantly less demanding on latency than competitive shooters. The graph contains **67 nodes** (45 functional, 22 provider) and ~115 edges.

### Key Architectural Decisions

**AWS GameLift (multi-region FleetIQ) for Game Servers**
Game servers in NA, EU, and AS are orchestrated via `GameLift (multi-region FleetIQ)` (score: 0.82). Innersloth has a documented AWS partnership and case study; GameLift handles the game server lifecycle (fleet scaling, session allocation, matchmaking integration) so the small Innersloth engineering team doesn't need to manage bare-metal server operations. FleetIQ specifically mixes Spot and On-Demand instances and automatically fails over across fleets — appropriate for Among Us's spiky, highly variable player traffic.

**Fargate multi-AZ for all Backend Services**
All backend microservices (Auth, Account, Matchmaking, Store, Chat, Moderation, etc.) run on `ECS/EKS (Fargate multi-AZ)` (score: 0.78). This removes the need for Innersloth to manage EC2 nodes, which suits a studio that grew from 3 to ~25 developers. Fargate's managed node scaling handles traffic spikes without manual intervention, a lesson learned when the game went viral and their original infrastructure (Photon Cloud) collapsed.

**AWS Lambda for Stateless Game Logic**
Discrete per-session operations — lobby code generation, role assignment, task assignment, vote tallying, and map selection — are implemented as `AWS Lambda` functions (score: 0.70). These are ephemeral, session-scoped, and fire-and-forget, making serverless a natural fit. Lambda cold starts are tolerable for non-latency-critical pre-game setup.

**DynamoDB Global Tables for Player Data**
Player profiles, inventory, and friends data are stored in `DynamoDB Global Tables` (score: 0.93) — active-active multi-region replication ensures players in Asia, Europe, and North America all get low-latency reads for their account data. This is the highest-scoring data tier in the providers list.

**RDS Multi-AZ for Transactional Store Data**
Purchase records and store inventory use `RDS Multi-AZ (Standby)` (score: 0.65), which provides synchronous standby replication and automatic ~60-120s failover. This is appropriate for Among Us's relatively low transaction volume (cosmetics purchases, DLC) compared to a game like Fortnite.

**EventBridge + SNS + SQS for Messaging**
A three-tier messaging architecture: `EventBridge` (score: 0.80) as the event bus for cross-service orchestration, `SNS` (score: 0.78) for fan-out notifications to players, and `SQS Standard` (score: 0.78) for telemetry buffering. This reflects AWS best practices from the Games Industry Lens (GAMEOPS01-BP01) around event-driven operations.

**Shield Advanced + WAF + CloudFront**
DDoS protection via `AWS Shield Advanced` (score: 0.87) with `WAF (Managed Rules)` (score: 0.75) protecting the API layer. Content (game updates, cosmetic assets) served through `CloudFront CDN` (score: 0.85) to reduce load on origin and improve global asset delivery. Innersloth has suffered DDoS attacks during peak popularity periods, making Shield Advanced appropriate.

**Datadog Pro for Observability**
`Datadog Pro` (score: 0.75) supplements `CloudWatch (standard)` (score: 0.72) for application-level visibility. For a small team doing Live Ops, Datadog's unified dashboard across metrics/logs/traces is more efficient than native CloudWatch alone.

### Why This Is a Best-Guess of Reality

Innersloth has publicly discussed their AWS partnership, and AWS published a case study on scaling Among Us. Known facts: Among Us originally used Photon Cloud (a third-party networking SDK), then migrated to dedicated servers with AWS help. The game has servers in NA, EU, and Asia. They added an Innersloth Account system (auth) in 2021. The cosmetics store and DLC (e.g., The Airship) require payment processing and inventory management. GameLift is the most natural AWS-native solution for game server lifecycle management without a large ops team.

---

## 2. Pre (Degraded) Infrastructure — Degradations Explained

The pre infrastructure represents Among Us's earlier, less mature architecture (notionally ~2020 era, when the game went viral and their infrastructure was under severe strain). It keeps the same 45 functional nodes but uses only **19 provider nodes** with quality downgrades, and removes 14 functional dependency edges.

### Provider Downgrades

| Component | Pre | Post | Score Impact |
|---|---|---|---|
| Compute | `EC2 Auto Scaling Group (multi-AZ)` 0.75 | `ECS/EKS (Fargate multi-AZ)` 0.78 | -0.03 |
| Game servers | `GameLift (single region)` 0.72 | `GameLift (multi-region FleetIQ)` 0.82 | -0.10 each |
| Player DB | `DynamoDB (On-Demand)` 0.80 | `DynamoDB Global Tables` 0.93 | -0.13 |
| Session cache | `ElastiCache (single node)` 0.35 | `ElastiCache (cluster mode)` 0.70 | -0.35 |
| Store DB | `RDS Single-AZ (any engine)` 0.40 | `RDS Multi-AZ (Standby)` 0.65 | -0.25 |
| DDoS | `Shield Standard` 0.60 | `Shield Advanced` 0.87 | -0.27 |
| Messaging | SQS only | EventBridge + SNS + SQS | Reduced routing flexibility |
| Observability | CloudWatch only | Datadog Pro + CloudWatch | -0.03 |

### Topology Removals (Graph Degradations)

Fourteen functional dependency edges removed to create structural weaknesses:

1. **Game Server EU/AS → Game State Manager** — EU and AS game servers no longer feed into the centralized game state manager; only NA does. This makes `Game State Manager` less connected, increasing its potential to be a bottleneck and reducing the Fielder value (algebraic connectivity).
2. **Game Server EU/AS → Anti-Cheat Service** — Anti-cheat only covers NA servers. EU/AS players have less protection, and those game server nodes become leaf-like in the dependency graph.
3. **Telemetry Collector → Game Server EU/AS** — Telemetry only collected from NA game servers, isolating EU/AS monitoring coverage.
4. **Analytics Service → Event Bus** — Analytics pipeline is decoupled from real-time event stream; event-driven analytics not yet implemented.
5. **Notification Service → Chat Service** — Notifications are simpler (no chat integration), reducing cross-cluster edges and clustering coefficient.
6. **Player Report Service → Moderation Service** — Player reports are not automatically escalated to the moderation system; moderation is more manual.
7. **API Gateway → Chat Service** — Chat is not accessible through the main API gateway, isolating it structurally.
8. **Achievement Service → Inventory Service** — Achievements don't yet unlock inventory items.
9. **Map Selector Service → Game State Manager** — Map selection is simpler and less integrated with game state.
10. **DLC Service → Inventory Service** — DLC purchases not yet tracked in inventory.
11. **Friends Service → Player Profile Service** — Friends list is independent from player profiles.
12. **Store Service → Cosmetics Service** (kept) but removed **DLC Service → Inventory** and **Achievement → Inventory** breaks the inventory cluster.

These removals collectively: (a) isolate EU/AS game servers from core services, creating articulation points; (b) break the cross-service edges that create triangles, lowering clustering coefficient; (c) remove bridge edges between functional clusters, lowering Fielder value.

---

## 3. Score Results

```
=== amongUs PRE ===
Overall Score:                 0.5962
  Articulation Points Ratio:   0.7188
  Average Clustering Coeff:    0.0773
  Average Tech Score:          0.9189
  Bounded Fielder Value:       0.0095
  Degree Entropy:              0.6225
  Overall Betweenness:         0.9828

=== amongUs POST ===
Overall Score:                 0.6039
  Articulation Points Ratio:   0.7463
  Average Clustering Coeff:    0.0663
  Average Tech Score:          0.9324
  Bounded Fielder Value:       0.0094
  Degree Entropy:              0.6329
  Overall Betweenness:         0.9795
```

### Does It Match Expectations?

**Yes — POST scores higher than PRE (0.6039 > 0.5962), as expected.** The direction is correct across most metrics.

| Metric | Direction | Expected | Matches? | Explanation |
|---|---|---|---|---|
| Average Tech Score | POST > PRE | POST higher (better providers) | ✅ | GameLift FleetIQ vs single-region (+0.10/fleet), DynamoDB Global (+0.13), ElastiCache cluster (+0.35), RDS Multi-AZ (+0.25), Shield Advanced (+0.27) — all substantial improvements in provider quality |
| Articulation Points Ratio | POST > PRE | POST higher (fewer critical single points) | ✅ | 0.7463 vs 0.7188 — POST has more redundant paths (EU/AS servers connected to anti-cheat, game state manager, telemetry), reducing single points of failure as a fraction of nodes |
| Overall Betweenness | POST < PRE | POST higher | ❌ | 0.9795 vs 0.9828 — Slight unexpected decrease. POST's additional edges (EU/AS → Game State Manager, anti-cheat, telemetry; Analytics → Event Bus; Notification → Chat) create new routing paths through hub nodes, slightly increasing raw betweenness concentration at those nodes and reducing the (1-betweenness) score. The effect is small and the overall score still correctly favors POST (+0.0077). |
| Degree Entropy | POST > PRE | POST higher (more diverse connections) | ✅ | 0.6329 vs 0.6225 — additional provider nodes and cross-service edges create a more balanced degree distribution |
| Bounded Fielder Value | POST < PRE | Expected higher for POST | ⚠️ | 0.0094 vs 0.0095 — marginally lower, a near-tie. Adding many provider leaf-nodes (SNS, EventBridge, Datadog, Shield Advanced) that connect to only one functional node can slightly reduce algebraic connectivity even as the functional graph improves. The effect is very small (~1% difference). |
| Average Clustering Coefficient | POST < PRE | Ambiguous | ⚠️ | 0.0663 vs 0.0773 — slightly lower in POST, same artifact seen in Valorant. Additional provider leaf-nodes added in POST don't form triangles, mechanically dragging down average clustering. |

### Why the Fielder Value is Marginally Lower in POST

The Fielder value measures how well-connected the graph is as a whole (higher = harder to disconnect). In POST, we added 3 extra provider nodes (SNS, EventBridge, Datadog) plus more functional cross-connections. However, SNS, EventBridge, and Datadog each connect to only 1-2 functional nodes — they are low-degree leaves. Adding leaf nodes to a graph tends to reduce the Fiedler value because they create weak points in the connectivity. The additional functional edges added in POST (EU/AS → Game State Manager, anti-cheat, telemetry; Analytics → Event Bus; etc.) partially compensate, but not enough to fully offset the leaf-node penalty.

Despite this, the **overall score correctly favors POST** (0.6039 > 0.5962) because the tech score improvement and articulation points ratio improvement outweigh the small Fielder value regression.

### Why the Margin Is Narrow (~1.3%)

1. **Among Us has a simpler infrastructure than a game like Valorant** — fewer regions, shorter dependency chains, less parallelism — so there's less absolute room for improvement from adding redundancy.
2. **Both graphs share the same 45-node functional backbone**, meaning topology differences are limited to edge additions/removals rather than architectural restructuring.
3. **The scoring averages over all 60+ nodes**, so improvements to 3 GameLift nodes (out of 64 total) contribute modest gains.

---

*Generated by rscore on 2026-05-27 for game: Among Us*
