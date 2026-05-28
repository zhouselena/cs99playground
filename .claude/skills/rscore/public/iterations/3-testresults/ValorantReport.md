# Valorant Infrastructure rscore Report

## 1. POST Infrastructure Summary

The POST graph models **Valorant's current (mature) production infrastructure** as operated by Riot Games, based on publicly available engineering blog posts, Riot's technology announcements, and the AWS Well-Architected Games Industry Lens.

### Key architectural components

| Layer | Description |
|-------|-------------|
| **Network edge** | Riot Direct — Riot's privately-operated BGP anycast network — acts as the outermost routing layer, backed by Cloudflare Magic Transit (BGP-level DDoS absorption) and Cloudflare Enterprise for WAF/proxy. AWS Shield Advanced provides additional SLA-backed DDoS response. |
| **Global routing** | AWS Global Accelerator provides anycast routing with automatic regional failover; Route 53 handles DNS health-based routing. A Global Load Balancer fans out to three regional NLBs (NA, EU, AP). |
| **Authentication** | Riot Sign On (RSO) is deployed on ECS/EKS Fargate across all three regions, making it highly available and eliminating single-region auth failures. |
| **Matchmaking** | Three independent regional matchmaking services (NA, EU, AP) allow each region to operate independently. This follows GAMEPERF07-BP02 ("Run a separate matchmaking service for each gameplay mode and game hosting Region"). |
| **Game servers** | AWS GameLift multi-region FleetIQ manages a fleet of five game server instances (NA-1, NA-2, EU-1, EU-2, AP-1), providing redundancy within each region. |
| **Player data** | Aurora Global Database for player profiles (cross-region replication, RTO < 1 min), DynamoDB Global Tables for match history and social graph (active-active, 99.999% availability). |
| **Session/presence** | MemoryDB for Redis (multi-region) provides durable, low-latency session state — critical for Valorant's lobby and party systems. |
| **Observability** | Dual observability stack: CloudWatch Container Insights for EKS-native metrics + Datadog Enterprise for cross-service full-stack traces. |
| **Anti-cheat** | Vanguard generates telemetry to a multi-shard Kinesis stream; match events flow through MSK (Managed Kafka multi-AZ). |
| **Content delivery** | Game patches distributed via S3 Standard + CloudFront CDN; AWS WAF restricts origin access to CloudFront only (GAMESEC04-BP02). |

### Why this is a credible model

Riot has publicly documented their use of Riot Direct BGP, their multi-region backend services, and their investment in low-latency game server infrastructure. The use of Aurora Global Database and DynamoDB Global Tables reflects AWS best practices for globally distributed gaming workloads (GAMEREL01-BP01). The multi-region Fargate deployment for RSO aligns with GAMESEC03-BP01 (central identity provider with high availability). The separation of regional matchmaking services follows the Games Industry Lens recommendation for per-region matchmaking.

**Total nodes: 66** (42 functional + 24 provider)

---

## 2. PRE Infrastructure: Degradations Made

The PRE graph models an **earlier, less mature version** of Valorant's infrastructure — resembling what the backend might have looked like circa early access (2020), before Riot fully scaled its global infrastructure.

### Degradations applied

| Degradation | POST | PRE | Graph Theory Impact |
|-------------|------|-----|---------------------|
| **Regional matchmaking removed** | 3 regional matchmaking services | 1 global matchmaking service | Matchmaking Service becomes an articulation point; no alternative path if it fails |
| **Regional load balancers removed** | 3 regional NLBs (NA/EU/AP) | 1 single global NLB | Global Load Balancer → Matchmaking becomes a single critical path; higher betweenness on both nodes |
| **Game server redundancy removed** | 5 game servers (2 NA, 2 EU, 1 AP) | 1 game server (NA only) | Game Server Manager → Game Server NA-1 is a linear chain; both are articulation points |
| **Multi-region compute removed** | Fargate multi-AZ in 3 regions | EC2 Auto Scaling Group in 1 region only | All services concentrated in AWS Compute NA; single-region failure takes down entire backend |
| **Database tier downgraded** | Aurora Global DB + DynamoDB Global Tables | RDS Multi-AZ (Standby) + RDS Single-AZ | Single-AZ RDS Match DB is a hard SPOF; 40–60s failover for Multi-AZ standby vs. <1s Aurora |
| **Session cache degraded** | MemoryDB for Redis (multi-region, score 0.88) | ElastiCache (single node, score 0.35) | Presence and Session Cache share one single-node cache; failure kills lobby/presence entirely |
| **DDoS protection degraded** | Cloudflare Magic Transit + AWS Shield Advanced | AWS Shield Standard only | No BGP-level DDoS absorption; no SLA; no dedicated DDoS Response Team |
| **Observability degraded** | Datadog Enterprise + CloudWatch Container Insights | CloudWatch Standard only | Reduced visibility; no cross-service tracing; slower incident detection |
| **Multi-region RSO removed** | RSO in 3 regions | RSO in NA only | Authentication becomes a single-region bottleneck; RSO failure is a global outage |
| **Cloudflare tier degraded** | Cloudflare Enterprise + Magic Transit | Cloudflare Pro | No 100% uptime SLA; no Magic Transit BGP-level protection; limited WAF rules |

### Why these should score worse

From a graph-theoretic perspective:
- **More articulation points**: Game Server Manager, Matchmaking Service, Global Load Balancer, and Riot Direct Network all become true articulation points in the PRE graph — removing any one disconnects a significant subgraph.
- **Lower algebraic connectivity (Fiedler value expected)**: The long dependency chain (Valorant Client → DDoS → Riot Direct → Global LB → Matchmaking → Game Server Manager → Game Server NA-1 → Anti-Cheat Telemetry) creates a path with minimal alternative routes, weakening the Fiedler value.
- **Lower tech scores**: ElastiCache single node (0.35), RDS Single-AZ (0.40), Shield Standard (0.60), Cloudflare Pro (0.65) vs. their POST counterparts substantially lower the average provider quality score.

**Total nodes: 49** (33 functional + 16 provider)

---

## 3. Results

```
PRE  Overall Score: 0.6197
POST Overall Score: 0.6225
```

### Full metric breakdown

| Metric | PRE | POST | Better |
|--------|-----|------|--------|
| Articulation Points Ratio | 0.8163 | 0.8182 | PRE (fewer relative articulation points) |
| Average Clustering Coefficient | 0.1087 | 0.0753 | PRE (denser local connectivity) |
| Average Tech Score | 0.8965 | 0.9362 | **POST** (higher-tier services) |
| Bounded Fiedler Value | 0.0395 | 0.0309 | PRE (smaller graph, higher connectivity) |
| Degree Entropy | 0.6782 | 0.6511 | PRE (more even degree distribution) |
| Overall Betweenness Centrality | 0.9481 | 0.9584 | PRE (less centralized traffic) |
| **Overall Score** | **0.6197** | **0.6225** | **POST** |

### Does this match expectations?

**Partially yes — POST is correctly scored higher than PRE**, confirming the model captures the infrastructure quality difference. However, the margin is very narrow (0.6225 vs 0.6197), and several individual graph metrics favor PRE. This warrants explanation.

### Why some graph metrics favor PRE

The counterintuitive result on structural metrics (Fiedler value, clustering coefficient, degree entropy) is explained by **graph size normalization effects**:

1. **Fiedler value (algebraic connectivity)**: The PRE graph has 49 nodes vs. 66 in POST. Smaller graphs tend to have higher Fiedler values because the same number of edges connects a smaller node set. A compact, tightly-coupled single-region deployment can appear more "connected" in the algebraic sense even though it is less resilient. In practice, the PRE graph has a single critical path for game sessions that the Fiedler metric does not fully penalize because the graph is small enough that even sparse graphs maintain acceptable connectivity ratios.

2. **Clustering coefficient**: Removing the three-way fan-out (three regional matchmaking services, three regional load balancers) eliminates hub nodes that inherently have low clustering coefficients (high-degree hubs reduce the average). The PRE graph's simpler topology incidentally produces more triangles relative to its size.

3. **Degree entropy**: POST's hub nodes (AWS Compute NA hosting many services, DynamoDB Match serving many functional nodes) create a more unequal degree distribution, lowering entropy. PRE's single compute region concentrates degree differently.

### What actually drives POST's win

The **Average Tech Score** (0.9362 vs 0.8965) is the decisive differentiator. The POST infrastructure uses significantly higher-reliability provider tiers — Aurora Global Database (0.90), DynamoDB Global Tables (0.93), MemoryDB multi-region (0.88), Shield Advanced (0.87), Cloudflare Magic Transit (0.85) — compared to PRE's ElastiCache single node (0.35), RDS Single-AZ (0.40), and Shield Standard (0.60).

### Conclusion

The rscore correctly identifies POST as a higher-quality infrastructure. The result aligns with expectations in direction (POST > PRE), though the narrow margin reveals an important limitation: **graph-theoretic metrics alone do not fully capture the reliability benefit of redundancy across regions**, since a smaller single-region graph can score comparably on connectivity metrics. The tech score component, which reflects provider-level SLA and reliability tiers, is essential for capturing the real resilience difference between a single-region and multi-region architecture.

For a more pronounced separation, future degradations should focus on creating explicit disconnections (isolated subgraphs) or removing critical bridge edges rather than collapsing regional redundancy, which paradoxically can improve some graph metrics.
