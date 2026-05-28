# Fortnite Infrastructure rscore Report

## 1. Post (Current) Infrastructure Summary

### What Was Modeled

The post infrastructure represents Fortnite's current production architecture (~2024-2025) as operated by Epic Games. Fortnite is one of the most demanding online games at scale: 100-player Battle Royale lobbies, Creative Mode sandbox servers, live in-game events with 12M+ concurrent players (Travis Scott 2020), V-Bucks microtransactions, and a cross-platform player base spanning PC, Console, and Mobile. The graph contains **77 nodes** (52 functional, 25 provider) and ~155 edges.

### Key Architectural Decisions

**Epic Account System (EAS) with OAuth**
Fortnite uses Epic's own identity platform (EAS), which supports login via Google, Facebook, Apple, Xbox, PlayStation, and Nintendo accounts through an OAuth Provider layer. This is reflected in the `OAuth Provider → Auth Service → Epic Account Service` chain. The auth service is multi-region on `ECS/EKS (Fargate multi-AZ)` (0.78), with session tokens stored in `MemoryDB for Redis (multi-region)` (0.88) for low-latency cross-region reads.

**Multi-Region EC2 Game Fleet with Creative Mode**
Game servers (NA, EU, AP, BR) and Creative Mode servers run on `EC2 Auto Scaling Group (multi-AZ)` (0.75) — direct EC2 fleet management rather than GameLift, appropriate for a studio of Epic's size that runs its own server orchestration at scale. Creative Mode servers share the same fleet but are modeled as a distinct functional component since they have meaningfully different game state requirements (persistent islands vs. ephemeral battle royale matches).

**Dual CDN: CloudFront + Cloudflare Enterprise**
Content delivery uses both `CloudFront CDN` (0.85) and `Cloudflare Enterprise` (0.88) in a dual-CDN configuration. Epic distributes game patches and assets at enormous scale; dual CDN provides geographic redundancy and allows routing around congestion. The CDN Edge node has hosted-on edges to both.

**Global Accelerator for Low-Latency Routing**
`AWS Global Accelerator` (0.87) underpins the Global Load Balancer for Anycast routing to the nearest AWS edge, reducing latency for API and matchmaking calls globally.

**Aurora Global + DynamoDB Global Tables + MemoryDB Multi-Region**
Three-tier data strategy:
- `DynamoDB Global Tables` (0.93) for player profiles, inventory, achievements, and battle pass state — active-active global replication
- `Aurora Global Database` (0.90) for transactional data (item shop, V-Bucks purchases, stats) — sub-1-minute RTO across regions
- `MemoryDB for Redis (multi-region)` (0.88) for session tokens, real-time game state, and presence — durable multi-region Redis

**Live Events Service**
Fortnite's live in-game concerts and events require routing into live game servers directly. `Live Events Service` depends on both `Game Server NA` and `Game Server EU` in addition to `Lobby Service`, reflecting the custom routing infrastructure used for massive synchronous events.

**Easy Anti-Cheat (EAC) Backend**
Epic owns Easy Anti-Cheat. The `Anti-Cheat Service` receives reports from all four game server regions (NA, EU, AP, BR), giving cross-region cheat detection coverage.

**Observability: Datadog Enterprise + CloudWatch Container Insights + OpenSearch**
Three-layer observability: `Datadog Enterprise` (0.82) for full-stack APM and dashboards; `CloudWatch (Container Insights)` (0.75) for ECS/EKS native metrics; `OpenSearch (multi-AZ with standby)` (0.75) as the log analytics backend for `Log Aggregation`. This reflects a large engineering org with specialized observability needs.

**Tournament Service**
Fortnite runs competitive Cups and Champion Series tournaments. The `Tournament Service` depends on `Matchmaking Service`, `Leaderboard Service`, and `Player Stats Service`, reflecting the three key systems required for competitive play.

### Why This Is a Best-Guess of Reality

Epic Games uses AWS as its primary cloud provider and has discussed this at re:Invent. They run EAS at global scale with OAuth integrations for 6+ platforms. Fortnite's CDN requirements (multi-gigabyte patches) are extreme and dual-CDN is consistent with public incident patterns where Fortnite patches have caused CDN stress. The Live Events Service is a real architectural component given Fortnite's documented massive in-game events. The MemoryDB choice for session state is consistent with Epic's need for Redis semantics with strong durability.

---

## 2. Pre (Degraded) Infrastructure — Degradations Explained

The pre infrastructure represents an earlier Fortnite (notionally ~2019 era, before full global scaling maturity). It keeps the same 52 functional nodes but uses only **20 provider nodes** with quality downgrades, and removes 21 functional dependency edges.

### Provider Downgrades

| Component | Pre | Post | Score Impact |
|---|---|---|---|
| DDoS | `Shield Standard` 0.60 | `Shield Advanced` 0.87 | -0.27 |
| Compute (backend) | `ECS/EKS (EC2-backed multi-AZ)` 0.72 | `ECS/EKS (Fargate multi-AZ)` 0.78 | -0.06 |
| Player DB | `DynamoDB (On-Demand)` 0.80 | `DynamoDB Global Tables` 0.93 | -0.13 |
| Store/Stats DB | `Aurora (Provisioned single region)` 0.78 | `Aurora Global Database` 0.90 | -0.12 |
| Session cache | `ElastiCache (single node)` 0.35 | `ElastiCache (cluster mode)` 0.70 | -0.35 |
| Session state | `MemoryDB (single region)` 0.76 | `MemoryDB (multi-region)` 0.88 | -0.12 |
| Observability | `Datadog Pro` 0.75 | `Datadog Enterprise` 0.82 | -0.07 |
| CDN | CloudFront only | CloudFront + Cloudflare Enterprise | Reduced redundancy |
| Routing | ALB only | ALB + AWS Global Accelerator | Reduced global reach |
| Logs | CloudWatch only | CloudWatch + OpenSearch | Reduced searchability |
| Analytics | No MSK Kafka | MSK Kafka multi-AZ | Removed stream decoupling |

### Topology Removals (21 edges removed)

1. **Game Server EU/AP/BR → Game State Manager** — only NA servers connect to centralized game state; EU/AP/BR exist but are isolated from state management
2. **Game Server EU/AP/BR → Anti-Cheat Service** — anti-cheat only covers NA, reflecting early-era incomplete global coverage
3. **Telemetry Collector → Game Server EU/AP/BR** — telemetry only from NA servers
4. **Creative Mode Server → Game State Manager** — Creative Mode not yet integrated with the main game state pipeline
5. **Tournament Service → Leaderboard Service and → Player Stats Service** — tournament service more limited, no direct stats/leaderboard integration
6. **Analytics Pipeline → Event Bus** — analytics not yet event-driven in real time
7. **Voice Chat Service → Squad Service** — voice chat less integrated
8. **Notification Service → Chat Service** — simpler notification system
9. **Achievement Service → Inventory Service** — achievements don't unlock inventory
10. **Friends Service → Squad Service** — friend-to-squad integration less mature
11. **Chat Service → Presence Service** — chat and presence decoupled
12. **Moderation Service → Epic Account Service** — manual moderation, not auto-linked to account actions
13. **Live Events Service → Game Server NA/EU** — live events routed only through lobby, not directly into game servers

---

## 3. Score Results

```
=== fortnite PRE ===
Overall Score:                 0.6287
  Articulation Points Ratio:   0.8194
  Average Clustering Coeff:    0.1221
  Average Tech Score:          0.9321
  Bounded Fielder Value:       0.0160
  Degree Entropy:              0.6358
  Overall Betweenness:         0.9833

=== fortnite POST ===
Overall Score:                 0.6246
  Articulation Points Ratio:   0.7922
  Average Clustering Coeff:    0.0932
  Average Tech Score:          0.9394
  Bounded Fielder Value:       0.0180
  Degree Entropy:              0.6690
  Overall Betweenness:         0.9847
```

### Does It Match Expectations?

**No — PRE scored slightly higher than POST (0.6287 > 0.6246), which is the opposite of what was expected.** However, this is explainable by a systematic artifact of the scoring model when many high-quality provider leaf-nodes are added.

| Metric | Direction | Expected | Matches? | Explanation |
|---|---|---|---|---|
| Average Tech Score | POST > PRE | POST higher | ✅ | 0.9394 vs 0.9321 — DynamoDB Global (+0.13), Aurora Global (+0.12), MemoryDB multi-region (+0.12), Shield Advanced (+0.27), Datadog Enterprise (+0.07). All improvements register correctly. |
| Bounded Fielder Value | POST > PRE | POST higher | ✅ | 0.0180 vs 0.0160 — POST has more edges (EU/AP/BR → Game State Manager, Anti-Cheat, Telemetry; Analytics → Event Bus, etc.), increasing algebraic connectivity. |
| Degree Entropy | POST > PRE | POST higher | ✅ | 0.6690 vs 0.6358 — POST has more diverse connections from additional provider nodes and functional edges. |
| Articulation Points Ratio | POST < PRE | POST should be HIGHER | ❌ | 0.7922 vs 0.8194 — **This is the key failure.** POST adds 5 extra provider nodes (NLB, MSK Kafka, OpenSearch, Global Accelerator, Cloudflare Enterprise), each connecting to exactly one functional node. Degree-1 leaf nodes ARE articulation points by definition (removing them disconnects their subtree). The net addition of 5 high-quality but low-degree provider leaf-nodes creates 5 extra articulation points, which outweighs the structural improvements from additional functional edges. |
| Average Clustering Coefficient | POST < PRE | Ambiguous | ⚠️ | 0.0932 vs 0.1221 — Same leaf-node artifact. Leaf nodes have clustering coefficient 0, and POST has more of them, dragging down the average substantially. |
| Overall Betweenness | POST > PRE | POST higher | ✅ | 0.9847 vs 0.9833 — POST's additional edges (voice chat to squad, analytics to event bus, EU/AP/BR anti-cheat coverage) create more distributed routing paths, increasing the betweenness score. The EC2 Game Fleet criticality drops from 0.5089 (PRE) to 0.2089 (POST) as POST's added edges distribute load away from that single bottleneck. |

### Root Cause Analysis: Why PRE Scored Higher

The fundamental issue is that POST adds **5 provider leaf-nodes** (AWS NLB, AWS MSK Kafka, AWS OpenSearch, AWS Global Accelerator, Cloudflare Enterprise) that each have degree 1 in the graph. In graph theory:

- **Leaf nodes are always articulation points** (in connected graphs, removing a leaf disconnects it)
- **Leaf nodes have clustering coefficient = 0** (no triangles can form through a node with only one neighbor)

The scoring model heavily weights articulation points ratio and clustering coefficient. Adding 5 leaf-nodes to a 77-node graph:
- Adds 5 articulation points, reducing the ratio from ~0.82 to ~0.79
- Lowers average clustering significantly (from 0.1221 to 0.0932)
- These two penalties (~-0.027 in ratio, ~-0.029 in clustering) cumulatively outweigh the tech score gain (+0.0073) and Fielder value gain (+0.002)

In contrast, PRE's 20 provider nodes are more uniformly high-degree (AWS Compute Services connects to 25+ functional nodes, AWS DynamoDB to 6+), which creates a graph with fewer leaf-induced articulation points and higher clustering.

### What This Reveals About the Scoring Model

This result highlights an important property of graph-based infrastructure scoring: **adding more cloud services is not always scored positively** if those services are architectural singletons (only one consumer). The model rewards redundant, well-connected service dependencies over specialized one-off integrations. In practice, the solution would be to model Cloudflare Enterprise and MSK Kafka as shared services with multiple consumers, rather than dedicated leaf connections. For example:
- CDN Edge AND Content Delivery Service could both depend on Cloudflare Enterprise
- Multiple analytics and event consumers could depend on MSK Kafka

This would turn leaf-nodes into higher-degree nodes, eliminating the articulation point and clustering penalties.

---

*Generated by rscore on 2026-05-27 for game: Fortnite*
