# League of Legends Infrastructure rscore Report

## 1. Post-Infrastructure Summary (Current State)

The "post" graph models the **current Riot Games / League of Legends cloud architecture** as it exists following Riot's full migration to AWS (completed ~2023). It contains **67 nodes** (51 functional, 16 provider) and **176 edges**.

### Key architectural choices and their justifications

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Compute | `AWS Compute` → ECS/EKS (EC2-backed multi-AZ) | Riot publicly documented migrating all 246 Kubernetes clusters to Amazon EKS with Karpenter for auto-scaling (AWS case study, re:Invent 2024 GAM307). EC2-backed multi-AZ gives control over node types needed for game server workloads. |
| Primary DB | `AWS Database` → Aurora Global Database | Riot migrated 2,000 databases to AWS managed services. Aurora Global Database's <1 min RTO across regions fits Riot's global player account needs (documented in AWS RDS case study). |
| Cache / session | `AWS ElastiCache` → ElastiCache (cluster mode) | Riot's Loot Service whitepaper explicitly mentions Memcached (ElastiCache-compatible) for caching loot state. Cluster mode adds sharding and replica failover. |
| NoSQL / game state | `AWS DynamoDB` → DynamoDB Global Tables | Matchmaking state and social graph require low-latency reads globally; DynamoDB Global Tables provides active-active multi-region at 99.999% SLA. |
| Global routing | `AWS Networking & Edge` → AWS Global Accelerator | Riot Direct (Riot's own BGP network) + Global Accelerator gives anycast routing, routing player traffic to the nearest AWS entry point before hitting services — reducing latency by 10–20 ms per AWS/Riot case study. |
| Load balancing | `AWS ALB` → Application Load Balancer | Managed, multi-AZ HTTP(S) routing for RiotSignOn and internal services. |
| DNS | `AWS Route 53` → Route 53 (Standard) | 100% uptime SLA; Riot recommends public DNS resolvers for LoL clients (LoL support docs reference DNS resolver issues). |
| CDN | `AWS CloudFront` + `Cloudflare Enterprise` | CloudFront for static assets/patches; Cloudflare Enterprise for DDoS mitigation and edge WAF, dual-CDN for resilience. |
| Messaging / events | `AWS Messaging & Queuing` → MSK (Managed Kafka multi-AZ) | Riot's data pipeline (analytics, game events) needs high-throughput ordered streams; Managed Kafka multi-AZ provides production-grade event streaming. |
| Event queuing | `AWS SQS` → SQS Standard | Notification and player behavior queues use SQS for decoupling. |
| Game server edge | `AWS Outposts` | Riot uses AWS Outposts to run game servers closer to players in metros, reducing peeker's advantage (documented in AWS case study). |
| Authentication | RiotSignOn | OAuth2/OpenID Connect SSO deployed in 4 AWS regions with regional pinning — Riot's published architecture. |
| Messaging layer | Riot Messaging Service | Replaced XMPP chat; Riot's published tech blog describes their Erlang-based pub/sub messaging service used for in-game and social notifications. |

### Graph structure (post)
- **3 regional game server clusters** (NA, EUW, APAC), each independently connected to Riot Messaging Service, Statistics, Logging, and Anti-cheat
- **Redundant CDN** via CloudFront + Cloudflare
- **Redundant game server hosting** via both main AWS Compute (EKS) and AWS Outposts (edge)
- **Rich feature set**: Champion Select Service, Tournament Service, Clan Service, Achievement Service, Player Behavior Service, Feature Flags, Configuration Service — reflecting LoL's mature 2024 microservice architecture

---

## 2. Pre-Infrastructure: Degradations Applied

The "pre" graph models an **older, less mature version** of the same infrastructure — roughly analogous to Riot's architecture circa 2017–2019, before full cloud migration and service maturation. It contains **49 nodes** (38 functional, 11 provider) and **117 edges**.

### Major degradations

| Degradation | Graph-theory effect | Score impact |
|-------------|---------------------|-------------|
| **Removed Game Server APAC** (only NA + EUW regions) | Removes 3 edges from Spectator Service, reduces redundant parallel paths to Riot Messaging/Statistics | Fewer alternative paths → higher articulation point risk for Riot Messaging Service |
| **Removed AWS Outposts** (no edge game server hosting) | Game Servers NA/EUW each lose 1 hosted-on edge | Reduces degree of game server nodes; less geographic redundancy |
| **Removed AWS Global Accelerator** → ALB only | AWS Networking & Edge tier drops from 0.87 to 0.80 score | Single entry-point for global routing; no anycast failover |
| **Aurora (Provisioned single region)** instead of Aurora Global Database | DB tier drops from 0.90 to 0.78 score | Regional DB failure = extended downtime; no cross-region replication |
| **ElastiCache (single node)** instead of cluster mode | Cache tier drops from 0.70 to 0.35 score | Cache is a single point of failure; no shard or replica failover |
| **DynamoDB (On-Demand)** instead of Global Tables | DynamoDB tier drops from 0.93 to 0.80 score | No multi-region active-active; regional DynamoDB failure impacts global players |
| **Kinesis (1 shard)** instead of MSK (Managed Kafka multi-AZ) | Messaging tier drops from 0.75 to 0.55 score | Single Kinesis shard is a throughput bottleneck; no Kafka HA |
| **Cloudflare Pro** instead of Enterprise | Cloudflare tier drops from 0.88 to 0.65 score | No dedicated SLA; less advanced WAF and DDoS protection |
| **Removed Container Orchestration node** | Removes bridge between orchestration and game server manager; increases articulation point risk for Game Server Orchestrator | Game server scaling is less automated |
| **Removed Anti-cheat Service** | Game Servers NA/EUW lose connections to anti-cheat; Game Server Orchestrator loses one downstream dependency | Vanguard didn't exist in early LoL; simpler security posture |
| **Removed Champion Select Service** | Removes 2 edges (→ Riot Messaging, → Game Server Orchestrator); Matchmaking now handles champion select inline | Fewer intermediate nodes reduces graph clustering around matchmaking |
| **Removed Tournament/Clan/Achievement/Player Behavior/Config/Feature Flag services** | Removes 12+ nodes and their edges | Significant reduction in graph density and clustering coefficient |
| **Removed VPN Gateway and Auth Token Cache** | Removes redundant auth paths and secure internal tunneling | Auth session path is simpler but less secure |
| **Custom DNS** instead of Route 53 | Unscored, custom DNS provider | No 100% SLA DNS; older LoL infra used ISP-prone DNS (documented in LoL support pages) |
| **Removed AWS Route 53, AWS API Gateway, AWS ALB, AWS Kinesis, AWS SQS** provider nodes | Networking is consolidated into one AWS Networking & Edge ALB node | Fewer specialized services = less overall redundancy |

---

## 3. Score Results

```
=== leagueOfLegends PRE ===
Infrastructure Resilience Score: 0.4998
  Articulation Points Ratio:       0.9184
  Average Tech Score:              0.0000
  Bounded Fielder Value:           0.0599
  Degree Entropy:                  0.7465
  Overall Betweenness Centrality:  0.9760

=== leagueOfLegends POST ===
Infrastructure Resilience Score: 0.5042
  Articulation Points Ratio:       0.9254
  Average Tech Score:              0.0000
  Bounded Fielder Value:           0.0488
  Degree Entropy:                  0.7825
  Overall Betweenness Centrality:  0.9722
```

### Does it match expectations?

**Partially yes — direction is correct, but margin is smaller than expected.**

The post score (0.5042) is higher than the pre score (0.4998), which matches expectations: the more mature, redundant post-infrastructure should score better.

However, the gap is very narrow (~0.004). The main reasons:

1. **Average Tech Score = 0.0000 for both**: The provider tier quality scoring is not being applied. This is likely because several provider nodes use custom names (e.g., `AWS ElastiCache`, `AWS DynamoDB`, `AWS CloudFront`, `AWS ALB`) that don't exactly match any `Provider` entry in providers.csv (all of these fall under `AWS Database` or `AWS Networking & Edge` in providers.csv). Since the exact node name doesn't match, no tier score is assigned. This means the intentional tier downgrades in the pre version (e.g., ElastiCache single node from 0.35 vs cluster mode 0.70) are **not reflected in the score** — the biggest differentiator between pre and post is invisible to the scorer.

2. **Mixed graph metrics**: The post graph's Articulation Points Ratio (0.9254) is actually slightly *higher* than pre's (0.9184), and its Fielder Value (0.0488) is slightly *lower* than pre's (0.0599). This is because the post graph has more nodes, which can introduce more articulation points in absolute terms even when the overall architecture is more robust. The larger graph also has a lower algebraic connectivity per-node as the network grows in complexity.

3. **Degree Entropy improvement**: The post scores clearly better here (0.7825 vs 0.7465), reflecting the more evenly distributed connectivity of the richer, more fully-featured architecture.

4. **Betweenness Centrality**: Post is slightly lower (0.9722 vs 0.9760), indicating slightly less dependence on hub nodes — a positive sign for resilience.

### What would make the score difference larger?

The scoring would better differentiate pre vs post if:
- Provider node names matched providers.csv exactly (e.g., using a single `AWS Database` node per database tier, even at the cost of architectural precision)
- The Average Tech Score mechanism could be activated — the tier quality difference alone (ElastiCache 0.35 → 0.70, Aurora 0.78 → 0.90, DynamoDB 0.80 → 0.93, Cloudflare 0.65 → 0.88) would create a significant gap

---

*Sources:*
- [Riot Games Cuts $10M Costs by Migrating to Amazon EKS](https://aws.amazon.com/solutions/case-studies/riot-games-case-study/)
- [Riot Games Prepares to Close Its Last Data Center](https://aws.amazon.com/blogs/gametech/riot-games-prepares-to-close-its-last-data-center-as-it-completes-global-migration-to-aws/)
- [Migrating 2,000 Databases with Riot Games](https://aws.amazon.com/solutions/case-studies/riot-games-rds-case-study/)
- [re:Invent 2024 GAM307: Effortless game launches on AWS](https://reinvent.awsevents.com/content/dam/reinvent/2024/slides/gam/GAM307_Effortless-game-launches-How-League-of-Legends-runs-at-scale-on-AWS.pdf)
- [Riot Messaging Service](https://technology.riotgames.com/news/riot-messaging-service)
- [Leveling Up Networking for a Multi-game Future](https://technology.riotgames.com/news/leveling-networking-multi-game-future)
- [Running Online Services at Riot: Part I](https://technology.riotgames.com/news/running-online-services-riot-part-i)
- [RSO (Riot Sign On) Documentation](https://support-developer.riotgames.com/hc/en-us/articles/22801670382739-RSO-Riot-Sign-On)
