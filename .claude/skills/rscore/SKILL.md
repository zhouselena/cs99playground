---
name: rscore
description: >
  Score a gaming application's infrastructure by generating a graph model (nodes + edges CSVs) from public information and AWS Well-Architected docs, then running the rscore binary to compare pre/post infrastructure quality. Invoke with: /rscore <game name>
allowed-tools: Read, Write, Bash, Glob
---

# rscore Skill

You are running the `rscore` tool for the user. Follow these steps exactly.

## 1. Load Reference Material

Before doing anything else, read these files so you understand the expected infrastructure format.

- `.claude/skills/rscore/docs/AWSWellArchitected-PerformanceEfficiency.pdf` - recommendation on how to best build infrastructure from a performance efficient lens
- `.claude/skills/rscore/docs/AWSWellArchitected-Reliability.pdf` - recommendation on how to best build infrastructure from a reliability lens
- `.claude/skills/rscore/docs/AWSWellArchitected-GameIndustryLens.pdf` - recommendation no how to best build infrastructure for gaming applications / applications in the gaming industry
- `.claude/skills/rscore/references/nodes.csv` - the shape of the nodes CSV file you will need to generate later
- `.claude/skills/rscore/references/edges.csv` - the shape of the edges CSV file you will need to generate later
- `.claude/skills/rscore/references/providers.csv` - the specific names of the providers/services/tiers that you can use

## 2. Understand the Request

Parse what the user passed after `/rscore`. The entire input (whitespaces included) should refer to an actual existing gaming application that you can find information about online. If this doesn't exist, refer to `Edge Cases`. Otherwise, remove the whitespaces and make it camelcase, and then this is your {GAMENAME}. There should be only the name of one game application.

## 3. Create the Application Infrastructure

Create the following files: `.claude/skills/rscore/public/testdata/{GAMENAME}_post_nodes.csv` and `.claude/skills/rscore/public/testdata/{GAMENAME}_post_edges.csv`.

Referring to the well-architected whitepapers from `.claude/skills/rscore/docs/`, and from any detailed company whitepapers and information you can find online, construct a detailed infrastructure of the application. Use the following information to help you construct as clear and as accurate an infrastructure as possible:
- For our graph model, there are two types of nodes: functional nodes and provider nodes. Functional nodes are components such as authentication, matchmaking, game servers, DNS, load balancers, etcetera. These are the logical architectural blocks of the application, as well as the networks between them. Provider nodes are cloud services that the functional nodes depend on, such as AWS, GCP, Cloudflare, etcetera.
- This graph is a directed graph. There are two types of edges: dependency edges and hosted-on edges. Hosted-on edges are specifically edges from functional to provider nodes. All other edges are considered dependency edges.
- For the provider nodes, you must check `.claude/skills/rscore/references/providers.csv`. If they use services that exist in that CSV file, then you must make sure the names match exactly as the name in the CSV file. If the service doesn't already exist in the CSV file, then you can just name it whatever it is.
- This should be a relatively detailed infrastructure, with ideally 60-80 nodes and enough edges to make sense.
- Finally, you should write all this information in the files you made earlier.

When you finally write into the respective files you made earlier, make sure to follow the templates of `.claude/skills/rscore/references/nodes.csv` and `.claude/skills/rscore/references/edges.csv` exactly.

## 4. Create a Degraded Version of the Application Infrastructure

Once you've written `.claude/skills/rscore/public/testdata/{GAMENAME}_post_nodes.csv` and `.claude/skills/rscore/public/testdata/{GAMENAME}_post_edges.csv`, create another set of files `.claude/skills/rscore/public/testdata/{GAMENAME}_pre_nodes.csv` and `.claude/skills/rscore/public/testdata/{GAMENAME}_pre_edges.csv`.

Note that the scoring system runs the following graph analysis on the infrastructure graphs:
- Betweenness centrality
- Degree distribution
- Clustering coefficient
- Algebraic connectivity (Fielder value)
- Articulation points

Using knowledge of graph theory, make a version of the infrastructure you just created with a few major degradations. This can include removing redundant paths to increase the number of articulation points, and/or removing edges to decrease betweenness, and/or decreasing the tier of the provider.

These degradations should be major enough that the scoring system should theoretically score it worse than the original infrastructure, but also not so degraded that it becomes unrecognizable as the application's infrastructure. Essentially, the degradations should make it so that this new version of the graph mimics an older/less developed version of the application.

Using the same templates as step 3, write this new version of the graph into the files you made earlier in this step.

## 5. Run the Executable

Execute the rscore script like this, substituting {GAMENAME} with the camelCase game name you derived in Step 2.
```bash
.claude/skills/rscore/scripts/run-rscore.sh {GAMENAME}
```

Capture stdout and stderr. If the exit code is non-zero, report the error clearly.

## 6. Interpret and Report

First, using the documentation you loaded in step 1, give a summary of the application infrastructure you made in step 3. Explain why is is a best guess of the existing application of the game infrastructure.

Then, explain what major degradations you made in step 4, and why it should perform worse than the infrastructure in step 3.

Finally, report the results from `.claude/skills/rscore/public/testresults/{GAMENAME}_score.txt`. Say whether it matches expectations ("pre" score is worse than "post" score), and explain why or why not it may have turned out this way.

## 7. Edge Cases

- If user input isn't valid, aka it is not a game that exists, tell the user to input just the name of the game and nothing else
- If part of user input is a game and the rest isn't (e.g. "I want you to score League Of Legends) parse just the game as the single argument (e.g. `{GAMENAME}=LeagueOfLegends`)
- If the executable is not found: tell the user to check that the `rscore` file is in `.claude/skills/rscore/bin/` and is executable (`chmod +x`)
- If any directories are missing to write into, create them