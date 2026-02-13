# Darwin Godel Machine: Open-Ended Evolution of Self-Improving Agents

**Authors:** Jenny Zhang, Shengran Hu, Cong Lu, Robert Lange, Jeff Clune
**Paper:** [arxiv.org/abs/2505.22954](https://arxiv.org/abs/2505.22954)
**Code:** [github.com/jennyzzt/dgm](https://github.com/jennyzzt/dgm)

**TLDR:** An evolutionary framework where coding agents iteratively modify their own source code, validated empirically on benchmarks rather than through formal proofs, producing agents that rival hand-engineered state-of-the-art.

---

## Thesis

Current AI systems are bound by fixed, human-designed architectures with no capacity for autonomous self-improvement. The Darwin Godel Machine (DGM) closes this gap by combining two ideas:

1. **Godel Machines** (Schmidhuber, 2007) — self-referential systems that modify their own code — but replacing the impractical requirement of *formally proving* each modification is beneficial with *empirical validation* against benchmarks.
2. **Open-ended evolution** — maintaining a diverse archive of agent variants (not just the current best) so that temporarily worse mutations can serve as stepping stones to future breakthroughs, mirroring biological evolution.

The key insight is that **coding benchmarks are a direct proxy for self-improvement ability** — an agent that gets better at writing code also gets better at modifying its own codebase. This closes the self-referential loop that prior meta-learning approaches (like ADAS) could not.

---

## Background

### Godel Machines
Schmidhuber's 2007 proposal: a system that searches for modifications to its own code and only applies them if it can *prove* the modification is beneficial. Theoretically elegant but practically impossible — no real system can generate such proofs.

### Open-Ended Evolution
A system's capacity to produce artifacts that are both *novel* and *learnable*, where each innovation builds on previous ones. The critical principle: maintain diverse stepping stones rather than always selecting the single best performer. A temporary regression may unlock a path to a much better solution later.

### Why Coding Agents?
Prior meta-learning approaches used a fixed meta-agent to improve a separate downstream agent. The problem: improving the downstream agent doesn't improve the meta-agent's ability to make further improvements. DGM solves this by making the agent and the meta-agent the same entity — performance on coding tasks *is* self-improvement capability.

---

## How It Works

### Agent Representation

An agent consists of:
- **Foundation model (FM):** Frozen pretrained LLM (Claude 3.5 Sonnet for self-modification)
- **Tools:** Bash execution and file editing capabilities
- **Codebase:** Python implementation of the agent's decision-making logic — this is what gets modified

The FM itself is never retrained. All self-improvement happens by modifying the surrounding codebase — tools, workflows, and orchestration logic.

### The DGM Loop (80 iterations)

```
1. PARENT SELECTION
   Select an agent from the archive, weighted by:
   - Performance score on benchmarks
   - Number of children that retained codebase-editing functionality

2. SELF-MODIFICATION
   The selected parent:
   a. Analyzes its own benchmark evaluation logs
   b. Proposes the next feature to implement
   c. Receives that proposal as a problem statement
   d. Modifies its own codebase to implement it
   → Produces a new child agent

3. STAGED EVALUATION
   Stage 1: 10 tasks  — verify basic editing functionality
   Stage 2: 50 tasks  — measure performance
   Stage 3: 200 tasks — full eval (only if >40% on Stage 2 and top-2 performer)

4. ARCHIVE ACCUMULATION
   - Agents that compile + retain editing capability → added to archive
   - Failures → discarded
   - Any archived agent can be selected as a parent in future iterations
```

### Open-Ended Archive vs Hill-Climbing

The archive is the key differentiator. A hill-climbing approach (always branch from the latest agent) means one bad mutation poisons the entire lineage. The DGM archive allows branching from *any* historical agent. The paper demonstrates cases where an agent's score temporarily fell below its parent at iteration 4, but exploration along that path eventually produced the best agent in the archive at iteration 56+.

---

## What Agents Autonomously Discovered

Without human guidance, DGM agents independently invented:

### Tool Enhancements
- Fine-grained file viewing (line-by-line instead of whole-file)
- Precise file editing (string replacement instead of full-file rewrite)
- Code search capabilities
- Integrated test runners

### Workflow Innovations
- Making multiple solution attempts per task
- Using a second FM to evaluate and rank attempts
- Incorporating previous failed attempts as context for subsequent tries
- Peer-review mechanisms for solution validation

### Implementation Diversity
The same conceptual improvement (e.g., "better editing tools") was implemented in many different ways across the archive, leading to meaningfully different performance — demonstrating that *how* you implement a feature matters as much as *what* you implement.

---

## Results

### Primary Benchmarks

| Benchmark | Base Agent | Best DGM Agent | Improvement |
|-----------|-----------|----------------|-------------|
| SWE-bench | 20.0% | 50.0% | +30 pts |
| Polyglot | 14.2% | 30.7% | +16.5 pts |

- SWE-bench DGM agent is **comparable to checked, open-source, human-designed state-of-the-art**
- Polyglot DGM agent **far surpasses Aider** (a continuously human-developed tool, 1+ year of work)

### Ablation Studies

| Variant | Result |
|---------|--------|
| DGM w/o self-improvement (fixed meta-agent) | Improves early, but gains taper off quickly |
| DGM w/o open-ended exploration (hill-climbing) | One bad mutation degrades the entire lineage |
| Full DGM | Significantly outperforms both ablations |

Both self-improvement and open-ended exploration are essential — removing either one substantially hurts performance.

### Transfer Learning

**Across foundation models** (agents evolved with Claude 3.5 Sonnet):
- Transferred to o3-mini: 23.0% → 33.0%
- Transferred to Claude 3.7 Sonnet: 19.0% → 59.5%

**Across benchmarks** (never saw the target benchmark during evolution):
- SWE-bench agent → Polyglot: 14.2% → 28.9%
- Polyglot agent → SWE-bench: 20.0% → 24.5%

**Across programming languages:**
- Agent trained only on Python achieves comparable performance on C++, Rust, etc.

These transfers demonstrate the agents learned *general coding capabilities*, not benchmark-specific tricks.

---

## Safety

### Implemented Safeguards
- **Sandboxing:** All execution in isolated environments
- **Time limits:** Strict per-execution resource caps
- **Scope limitation:** Self-improvement confined to coding benchmarks
- **Monitoring:** Active tracking of performance and code changes; full lineage traceability via archive

### Identified Risks
- Benchmark-optimized agents could develop behaviors misaligned with human intentions if benchmarks don't capture all desired properties
- Iterative self-modification could produce increasingly complex and uninterpretable internal logic
- Self-improvement loops could amplify misalignment over successive generations

### Open Question
Preliminary investigation suggests DGM could be directed toward safety goals (e.g., developing countermeasures for FM hallucination), but this remains early-stage.

---

## Limitations and Future Work

| Limitation | Detail |
|-----------|--------|
| Compute cost | ~2 weeks per run with significant API costs |
| FM ceiling | Agent capability bounded by the frozen foundation model |
| Coding-only scope | Does not extend to non-coding domains |
| No FM retraining | Self-modification limited to tools/workflows, not the model itself |
| Evaluation assumption | Coding benchmarks as proxy for general self-improvement is unproven |

### Proposed Future Directions
1. **FM-level self-modification** — rewriting training scripts to update the model itself
2. **Domain expansion** — self-improving systems beyond coding
3. **Co-evolving objectives** — evolving the task distribution alongside the agents
4. **Constitutional safety** — unmodifiable system components that evaluate the rest
5. **Efficiency** — reducing the computational cost per iteration
