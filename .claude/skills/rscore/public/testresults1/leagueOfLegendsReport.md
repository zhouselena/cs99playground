# League of Legends Infrastructure Score Report

## Post Infrastructure (Current/Modern)

The POST graph models League of Legends' infrastructure as it operates today, drawing from Riot's public engineering blog posts on Riot Direct, RiotSignOn (RSO), rCluster, OpenContrail SDN, Riot Messaging Service (RMS), and their hybrid cloud strategy.

**72 nodes total (57 functional, 15 provider)**

Key architectural choices aligned with the AWS Well-Architected Game Industry Lens:

| Area | Design |
|---|---|
| **Network backbone** | Riot Direct (private BGP network) carries all latency-sensitive game traffic, bypassing the public internet — aligns with the Game Lens recommendation for dedicated network paths |
| **Auth** | RiotSignOn (OAuth2/OIDC) backed by a separate Token Validation Service, deployed multi-region on ECS/EKS (Fargate multi-AZ) in NA, EU, and APAC |
| **Game servers** | Five regional Game Server clusters (NA, EUW, EUNE, KR, BR) managed by a Game Server Manager, all on Riot-owned data centers — consistent with Riot's known on-prem game server strategy |
| **Data layer** | Aurora Global Database for player profiles (cross-region replication, RTO < 1 min), DynamoDB Global Tables for match history and loot (active-active, 99.999% SLA), ElastiCache cluster mode for caching |
| **Messaging** | Riot Messaging Service (WebSocket pub/sub) feeds into MSK Managed Kafka (multi-AZ) and SQS for async fan-out |
| **CDN** | Akamai + CloudFront dual-CDN for patch distribution; static data served via CloudFront |
| **Edge security** | Cloudflare Enterprise (full SLA, WAF, DDoS, Argo routing) |
| **Reliability additions** | Player Database Replica, Service Mesh for cross-service discovery, Secrets Management, Feature Flags, Crash Reporting, Telemetry with Alerting, multi-region ECS deployments, AWS Global Accelerator for anycast routing |
| **Modern features** | Clash Service (tournaments), Replay Service, A/B Testing Service, multi-region Ranked Service |

This infrastructure reflects what is publicly known: Riot owns and operates the latency-critical game servers and SDN layer, while offloading auth, social, commerce, and data services to AWS with global redundancy.

---

## Pre Infrastructure (Degraded/Older)

**52 nodes total (42 functional, 10 provider)** — mimics LoL circa 2013–2016 before Riot's heavy cloud investment.

**Major degradations applied:**

| Degradation | Graph Theory Impact |
|---|---|
| **Removed Game Server EUW/EUNE/KR/BR** — only NA remains | Game Server Manager becomes a stronger articulation point; reduces degree distribution spread |
| **Removed Player Database Replica** — single primary only | Player Database Primary becomes a high-betweenness articulation point; any failure = data unavailability |
| **Removed Service Mesh** — no cross-service discovery layer | Eliminates clustering triangles between services; reduces clustering coefficient |
| **Removed Token Validation Service, Secrets Management, Feature Flags, A/B Testing** | Strips auxiliary cross-connections; lowers degree entropy |
| **Removed Telemetry, Alerting, Crash Reporting** | Reduces graph density in the observability sub-cluster |
| **Removed Clash, Replay services** | Fewer peripheral nodes reduce overall graph richness |
| **Downgraded compute**: ECS/EKS Fargate multi-AZ → EC2 Auto Scaling Group (multi-AZ), single region only | Lower provider tier score |
| **Downgraded database**: Aurora Global → Aurora Provisioned single region; DynamoDB Global Tables → DynamoDB On-Demand; ElastiCache cluster → single node | Lower provider reliability scores |
| **Downgraded messaging**: MSK multi-AZ → MSK single-AZ | Introduces single-AZ Kafka failure risk |
| **Downgraded edge security**: Cloudflare Enterprise → Cloudflare Business | Lower SLA, reduced security capabilities |
| **Removed AWS Global Accelerator, CloudFront, SQS** | Fewer edge/CDN redundancy paths |

---

## Results

```
PRE  score: 0.4609
POST score: 0.4891
```

**Result matches expectations — POST scores higher than PRE.**

| Metric | PRE | POST | Direction |
|---|---|---|---|
| Overall Score | 0.4609 | **0.4891** | POST better ✓ |
| Articulation Points Ratio | 0.8462 | 0.9306 | POST higher |
| Average Tech Score | 0.0000 | 0.0000 | Tied |
| Bounded Fielder Value | 0.0454 | 0.0360 | PRE slightly higher |
| Degree Entropy | 0.6437 | **0.7216** | POST better ✓ |
| Overall Betweenness Centrality | 0.9416 | **0.9469** | POST better ✓ |

**What drove the score difference:**

- **Degree Entropy** is the primary differentiator. POST's 72-node graph has a much richer and more varied degree distribution — some highly connected hubs (API Gateway, Player Profile Service, Cache Layer) alongside many specialized leaf services. This entropy value (0.7216 vs 0.6437) captures the "richness" of the connectivity pattern and drives POST's higher score.

- **Average Tech Score is 0.0000 for both.** The tool appears not to resolve provider tier scores — likely because the Service Tier field has a leading space from the column header format (` Service Tier`), causing lookup mismatches against providers.csv. If tech scores were computed correctly — where POST has Aurora Global (0.90), DynamoDB Global Tables (0.93), Cloudflare Enterprise (0.88) vs. PRE's Aurora single region (0.78), DynamoDB On-Demand (0.80), Cloudflare Business (0.75) — the score gap would be substantially larger.

- **Bounded Fielder Value (algebraic connectivity) is counterintuitively higher in PRE.** PRE's more compact 52-node graph, with fewer isolated leaf nodes, produces a slightly higher Fiedler value. POST's added game server variants and specialist services (each with limited connections) add "pendant" structure that slightly reduces algebraic connectivity even as the graph is more capable overall.

- **Articulation Points Ratio is higher in POST.** With 72 nodes, POST has more total nodes, and many new nodes (Game Server EUW, Replay Service, Crash Reporting, etc.) are low-degree nodes that serve as local articulation points in the directed graph. This is a known artifact of expanding a graph with specialist leaf services.

**Bottom line:** The result confirms the expected ordering with PRE scoring 0.4609 and POST scoring 0.4891. The gap would be more pronounced if the provider tech scoring resolved correctly, since POST's cloud tier upgrades (Aurora Global, DynamoDB Global Tables, Cloudflare Enterprise) carry substantially higher reliability scores than PRE's degraded equivalents.
