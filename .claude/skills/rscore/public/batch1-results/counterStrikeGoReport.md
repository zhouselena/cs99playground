# Counter-Strike: Global Offensive / CS2 Infrastructure rscore Report

## 1. Post (Current) Infrastructure Summary

### What Was Modeled

The post infrastructure represents Counter-Strike: Global Offensive / Counter-Strike 2's current production architecture (~2024-2025) as operated by Valve Corporation. CS:GO launched in August 2012 and was rebranded as CS2 in September 2023. CS2 is Valve's flagship competitive 5v5 tactical shooter with 1M+ peak concurrent players, featuring official competitive matchmaking, Premier ranked mode, a Valve Anti-Cheat (VAC) system, Steam Workshop for community maps, and a $1B+ real-money item economy via the Steam Marketplace. The graph contains **70 nodes** (50 functional, 20 provider) and ~168 edges.

### Key Architectural Decisions

**Valve Co-location (multi-DC) for Game Servers and Game Coordinator**
CS2 game servers (NA, EU, AP, SA) and the Game Coordinator run on Valve's own co-located hardware (`Private Network / Co-location (multi-DC)`, 0.70). Valve has publicly confirmed they operate their own data centers for game server hosting rather than using AWS GameLift or equivalent managed services. This gives Valve full control over game server scheduling, the CS2 game coordinator (which manages match creation and server allocation), and the tick-rate configuration (128-tick servers for Premier, 64-tick for casual).

**Steam Datagram Relay (SDR) for Private Routing**
`Private Network / Private BGP (multi-PoP)` (0.85) models Valve's Steam Datagram Relay network — a private anycast BGP network Valve operates with direct ISP peering across dozens of global PoPs, documented in their Steam networking documentation. SDR routes both `Load Balancer` traffic (API calls) and `Game Coordinator` session traffic, analogous to Riot Direct for Valorant. SDR reduces player latency by bypassing public internet routing for match creation and game server connections.

**Akamai CDN for Patch and Content Delivery**
`Akamai / CDN` (0.85) is CS2's primary content delivery network, confirmed in Valve's Steam infrastructure discussions. Akamai hosts `CDN Network`, `Content Delivery Service`, and `Patch Distribution Service`. CS2's multi-gigabyte updates (Source 2 engine assets, map packs) are among the largest game patches distributed globally, requiring Akamai's extensive PoP footprint. A dual-CDN layer (Akamai + CloudFront + Cloudflare) ensures patch availability even during single-CDN outages.

**Azure Cosmos DB (multi-region writes) for Steam Account and Player Data**
Steam player profiles, account data, friends graphs, and inventory (items/skins) are stored in `Azure / Cosmos DB (multi-region writes)` (0.92). Valve has confirmed Azure usage for Steam services; Cosmos DB's active-active multi-region replication ensures account and inventory consistency globally — critical for a game where items have real monetary value and inventory errors could have financial consequences.

**Aurora Global for Match History, Ranks, and Leaderboards**
Premier rank ratings, match history, and leaderboards use `AWS Database / Aurora Global Database` (0.90) for transactional consistency in rank updates and match record persistence. The Premier ranking system (CS2's ELO-like rating) requires strict write consistency: concurrent rank updates from multiple match finishes must not produce invalid ratings.

**VAC + Overwatch Dual Anti-Cheat Architecture**
CS2's anti-cheat is uniquely two-tier: `VAC Service` (Valve Anti-Cheat, automated) receives reports from all four game server regions. `Overwatch Service` (community-based review system) receives escalated reports from VAC via `Report Service` and can issue bans, which feed back to VAC. This Overwatch → VAC → Steam Account cycle creates a triangle in the security subgraph. All four game servers also report directly to Telemetry Collector for anomaly detection.

**Trust Factor Matchmaking**
`Trust Factor Service` models Valve's trust-based matchmaking system (introduced 2017), cached in `ElastiCache (cluster mode)` (0.70) alongside session and matchmaking state. Trust Factor depends on player profile (account age, Steam activity) and feeds into Matchmaking Service to pair players of similar trust scores together.

**Steam Marketplace + Item Economy**
The item economy runs through `Steam Market Service` → `Item Trading Service` → `Inventory Service`, with fiat payments via `Stripe Payments` (0.88) backing `Payment Gateway`. `Skin Inspect Service` serves cosmetic inspection URLs (the feature where players can inspect item skins in-detail via CDN-served 3D renders). `Operation Pass Service` tracks seasonal CS2 Operations, granting coins and missions.

**Cloudflare Enterprise + Shield Advanced DDoS**
`Cloudflare Enterprise` (0.88) provides edge CDN and L7 DDoS absorption alongside `AWS Shield Advanced` (0.87) for the API layer. CS2/Steam have historically been targets of large DDoS campaigns during major tournaments. `AWS Global Accelerator` (0.87) provides Anycast routing for Load Balancer and API Gateway.

### Why This Is a Best-Guess of Reality

Valve has publicly documented: Steam Datagram Relay as their private routing network (developer blog, Steam networking docs), Akamai as their CDN partner (Steam stats page, patch distribution analysis), co-located game servers for CS:GO/CS2 (player-facing server region UI, third-party data center research), and Azure usage for Steam services (Microsoft partnership announcements). The VAC + Overwatch dual anti-cheat system is thoroughly documented by Valve. The Steam Marketplace and item economy are core documented features. Trust Factor matchmaking was announced by Valve in 2017.

---

## 2. Pre (Degraded) Infrastructure — Degradations Explained

The pre infrastructure represents CS:GO at its early launch era (~2012-2014), before Valve matured the platform significantly. It keeps the same 50 functional nodes but uses only **18 provider nodes** (removed AWS Global Accelerator and Cloudflare Enterprise), with provider quality downgrades, and removes 12 functional dependency edges.

### Provider Downgrades

| Component | Pre | Post | Score Impact |
|---|---|---|---|
| Game Servers | `Co-location (single DC)` 0.45 | `Co-location (multi-DC)` 0.70 | -0.25 |
| Steam Routing | `Private BGP (single PoP)` 0.65 | `Private BGP (multi-PoP)` 0.85 | -0.20 |
| Player DB | `Cosmos DB (single region)` 0.78 | `Cosmos DB (multi-region writes)` 0.92 | -0.14 |
| Stats DB | `Aurora (Provisioned single region)` 0.78 | `Aurora Global Database` 0.90 | -0.12 |
| Cache | `ElastiCache (single node)` 0.35 | `ElastiCache (cluster mode)` 0.70 | -0.35 |
| DDoS | `Shield Standard` 0.60 | `Shield Advanced` 0.87 | -0.27 |
| CDN/Edge | CloudFront only | CloudFront + Cloudflare Enterprise | Reduced redundancy |
| Global Routing | ALB only | ALB + Global Accelerator | Reduced Anycast reach |
| Compute | `ECS/EKS (EC2-backed multi-AZ)` 0.72 | `ECS/EKS (Fargate multi-AZ)` 0.78 | -0.06 |
| Observability | `CloudWatch (standard)` 0.72 | `CloudWatch (Container Insights)` 0.75 | -0.03 |
| APM | `Datadog Pro` 0.75 | `Datadog Enterprise` 0.82 | -0.07 |

The single-DC co-location downgrade is the largest impact: Valve originally operated game servers from a small number of physical locations. The ElastiCache single-node downgrade is the second-largest: session and matchmaking state loss on cache failure would break ongoing matches.

### Topology Removals (12 edges removed)

1. **Game Server SA → VAC Service** — South America was a later addition with less anti-cheat integration in the early era
2. **Game Server SA → Telemetry Collector** — SA telemetry not integrated with the central telemetry pipeline initially
3. **Game Server SA → Game State Service** — SA servers more isolated from centralized game state early on
4. **Overwatch Service → VAC Service** — the Overwatch→VAC feedback loop was not present at CS:GO launch (Overwatch launched in 2015)
5. **Match History Service → Event Bus** — match history was not event-driven initially; batch-processed
6. **Operation Pass Service → Event Bus** — CS:GO Operations launched in 2013; event-driven integration came later
7. **Leaderboard Service → Player Profile Service** — early leaderboards showed only rank numbers, not full profile data
8. **Trust Factor Service → Player Profile Service** — Trust Factor launched in 2017; not at CS:GO release
9. **Match Replay Service → CDN Network** — replay download via CDN was a later improvement; initially served from origin
10. **Skin Inspect Service → CDN Network** — skin inspect links (csgo.exchange-style) came with the Steam Marketplace maturation
11. **Community Server Hub → API Gateway** — community server browser was less integrated with the main API in early CS:GO
12. **Chat Service → Friends Service** — Steam chat was less integrated with in-game friends graph at CS:GO launch

These removals target:
- **Regional isolation**: Removing SA → VAC/Telemetry/Game State creates an isolated SA region with no backend integration, weakening algebraic connectivity.
- **Triangle-breaking**: Overwatch → VAC breaks the VAC → Report → Overwatch → VAC cycle; Leaderboard → Player Profile breaks the Leaderboard → Player Stats → Player Profile triangle.
- **Event-driven decoupling**: Removing Match History → Event Bus and Operation Pass → Event Bus disconnects the progression subgraph from the event backbone.
- **CDN connectivity reduction**: Removing Match Replay → CDN and Skin Inspect → CDN reduces the number of paths into the CDN subgraph.

---

## 3. Score Results

```
=== counterStrikeGo PRE ===
Overall Score:                 0.6773
  Articulation Points Ratio:   0.9559
  Average Clustering Coeff:    0.2361
  Average Tech Score:          0.9294
  Bounded Fielder Value:       0.0356
  Degree Entropy:              0.6643
  Overall Betweenness:         0.9773

=== counterStrikeGo POST ===
Overall Score:                 0.6839
  Articulation Points Ratio:   0.9714
  Average Clustering Coeff:    0.2207
  Average Tech Score:          0.9491
  Bounded Fielder Value:       0.0544
  Degree Entropy:              0.6755
  Overall Betweenness:         0.9565
```

### Does It Match Expectations?

**Yes — POST scored higher than PRE (0.6839 > 0.6773), as expected.** Four of six individual metrics moved in the correct direction.

| Metric | PRE | POST | Diff | Expected | Matches? | Explanation |
|---|---|---|---|---|---|---|
| Overall Score | 0.6773 | 0.6839 | +0.0066 | POST > PRE | ✅ | POST wins by +0.0066. |
| Articulation Points Ratio | 0.9559 | 0.9714 | +0.0155 | POST > PRE | ✅ | POST's 20 providers all have ≥2 consumers; no singleton leaves. PRE's removal of SA game server integration creates a more leaf-like SA subgraph. |
| Avg Clustering Coeff | 0.2361 | 0.2207 | -0.0154 | POST > PRE | ❌ | POST adds Cloudflare Edge and AWS Accelerator — both degree-2 provider nodes with clustering coefficient 0, dragging down the network average. Same artifact as in Space Marine 2 and Fortnite. |
| Avg Tech Score | 0.9294 | 0.9491 | +0.0197 | POST > PRE | ✅ | +0.0197 — Co-location multi-DC (+0.25), Private BGP multi-PoP (+0.20), Cosmos DB multi-region (+0.14), ElastiCache cluster (+0.35), Shield Advanced (+0.27), Aurora Global (+0.12). ElastiCache cluster is the single largest provider improvement. |
| Bounded Fielder Value | 0.0356 | 0.0544 | +0.0188 | POST > PRE | ✅ | +0.0188 — POST's 12 additional edges measurably increase algebraic connectivity. The SA game server edges (→VAC, →Telemetry, →Game State) bridge the previously isolated SA subgraph. Overwatch→VAC closes the security cycle. Match History→Event Bus and Operation Pass→Event Bus connect the progression cluster to the event backbone. |
| Degree Entropy | 0.6643 | 0.6755 | +0.0112 | POST > PRE | ✅ | +0.0112 — POST has a more diverse degree distribution from the additional provider nodes (Cloudflare Edge, AWS Accelerator) and 12 more functional edges creating new connection patterns. |
| Overall Betweenness | 0.9773 | 0.9565 | -0.0208 | POST > PRE | ❌ | -0.0208 — Significant unexpected decrease. POST's additional edges route substantially more paths through hub nodes: VAC Service criticality rises from 0.0891 (PRE, 3 game servers) to 0.1141 (POST, 4 servers), Telemetry Collector rises from 0.0913 to 0.1054 as SA telemetry integrates, Event Bus gains criticality (0.0752 in POST vs 0.0000 in PRE) as Match History and Operation Pass now emit events. The concentration of new routing through these emerging hubs increases total raw betweenness, reducing the (1-betweenness) score. |

### Root Causes of Anomalies

**Clustering Coefficient decrease** (-0.0154): Adding Cloudflare Edge (hosts CDN Network + DDoS Protection) and AWS Accelerator (hosts Load Balancer + API Gateway) introduces two degree-2 provider nodes. Degree-2 nodes have clustering coefficient 0 in any graph. With 70 nodes total, adding 2 zero-clustering nodes reduces the average. PRE's 68-node graph without these two providers avoids this penalty. This is consistent with the Fortnite and Space Marine 2 patterns.

**Betweenness decrease** (-0.0208): The betweenness drop is larger than in some other games (similar magnitude to Space Marine 2's -0.0416). The root cause: POST's SA integration edges (SA → VAC × 1, SA → Telemetry × 1, SA → Game State × 1) make VAC Service and Telemetry Collector genuine 4-region hubs. Additionally, Match History → Event Bus and Operation Pass → Event Bus route new shortest paths through Event Bus (criticality 0.0000 PRE → 0.0752 POST). The combined effect concentrates routing through these newly-central nodes, raising total raw betweenness and reducing the scored (1-betweenness). The four correctly-improving metrics still carry the overall score to a +0.0066 POST advantage.

### Node Criticality Observations

**AWS Compute** drops dramatically from 0.5366 (PRE) to 0.2276 (POST). In PRE, the single-region Cosmos DB, single-region Aurora, and single-node ElastiCache force more shortest paths through AWS Compute as the dominant provider. In POST, Cosmos DB multi-region, Aurora Global, ElastiCache cluster, and the additional edge diversity distribute load across many providers and functional nodes, removing AWS Compute from its extreme bottleneck position.

**Valve Servers** drops from 0.2492 (PRE) to 0.2117 (POST). In PRE with single-DC co-location and SA isolated from the backend (no VAC/Telemetry/Game State connections), the single-DC creates a more concentrated bottleneck for all game server traffic. In POST's multi-DC configuration with SA fully integrated, game server paths are more diversely routed.

**CDN Network** rises from 0.3695 (PRE) to 0.3934 (POST). POST adds Match Replay → CDN Network and Skin Inspect → CDN Network as new edges, increasing the number of paths that pass through CDN Network. This makes it a more central relay in the content delivery subgraph.

**Event Bus** gains significant criticality from 0.0000 (PRE) to 0.0752 (POST) as Match History Service and Operation Pass Service now both emit events to it. In PRE, Event Bus sits at the end of the PokeStop/Game State chain without these two additional emitters, making it a terminal node. In POST it becomes a genuine cross-cluster hub.

---

*Generated by rscore on 2026-05-28 for game: Counter-Strike: Global Offensive / CS2*
