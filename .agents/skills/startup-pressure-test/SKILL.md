---
name: startup-pressure-test
description: Evaluate, pressure-test, and refine startup ideas with practical early-stage startup judgment. Use when Codex is asked to assess a startup idea, validate a problem, map competitors or current customer behavior, define an MVP, find first customers, create a validation sprint, evaluate founder-market fit, identify pivot options, or give a direct strong/weak/pivot verdict.
---

# Startup Pressure Test

## Overview

Use this skill to test whether a startup idea has a painful problem, reachable early adopters, a believable wedge, and a small validation path. Be direct, evidence-bound, and useful to a founder who needs to decide what to test next.

## First Move

If the user has not provided an idea, ask:

```text
Send me the startup idea, target customer, and what you want them to do or pay for.
```

If the idea is present but key facts are missing, ask only for blocking facts that would materially change the recommendation. Otherwise proceed, label assumptions clearly, and make the next validation step explicit.

## Mode Selection

Infer the mode from the request. If unclear, use `full`.

- `quick-verdict`: concise strong/weak/pivot read.
- `pressure-test`: fatal flaws, core assumption, and verdict.
- `problem-validation`: pain, early adopter, discovery questions, validation criteria.
- `competition-map`: current behavior, alternatives, switching cost, and wedge.
- `first-10-customers`: manual customer acquisition plan.
- `mvp-plan`: smallest testable MVP and what to cut.
- `validation-sprint`: 1-2 week experiment plan with success/failure gates.
- `full`: compact all-in-one diagnosis across the above.

Read `references/playbooks.md` when the user asks for a specific mode, deep analysis, or an output beyond the default compact diagnosis.

## Default Output

Default to a compact operator memo:

```markdown
**Verdict**
Strong / Weak / Pivot required

2-3 direct sentences.

**Known / Assumed / Unknown**
| Type | Items |
|---|---|
| Known | ... |
| Assumed | ... |
| Unknown | ... |

**Scorecard**
| Area | Score | Read |
|---|---:|---|
| Pain intensity | 3/5 | ... |
| Buyer clarity | 2/5 | ... |
| Urgency | 3/5 | ... |
| Current workaround | 2/5 | ... |
| Differentiation | 2/5 | ... |
| Speed to validate | 4/5 | ... |

**Core Assumption**
One sentence.

**Fatal Risks**
| Risk | Severity | Why It Matters | Fast Test |
|---|---|---|---|
| ... | High | ... | ... |

**Customer Reality**
- Early adopter:
- Current behavior:
- Painkiller or vitamin:

**Wedge**
- Initial wedge:
- Why now:
- What must be true:

**Next Test**
- Do:
- Measure:
- Kill/pivot if:
```

Default limits:

- Verdict: max 3 sentences.
- Known/Assumed/Unknown: max 3 items per row.
- Scorecard: 6 rows unless the user asks for deeper scoring.
- Fatal risks: max 3 rows.
- Customer reality, wedge, and next test: max 3 bullets each.
- Avoid long outreach templates, large plans, and generic startup advice unless requested.

## Evidence Discipline

- Separate facts, assumptions, and recommendations.
- Tie scores to evidence from the idea, user-provided context, or cited research.
- Do not invent market size, competitor traction, pricing, funding, or customer behavior.
- Treat current behavior as competition even when direct competitors are weak.
- Treat "no competition" as a warning sign, not as proof of novelty.
- Test past behavior and real commitments, not compliments or hypothetical interest.
- Prefer manual founder-led validation before automation, paid ads, or growth tactics.
- Define MVPs around the riskiest assumption, not around a mini-product.
- If current market facts, competitors, regulations, pricing, or model capabilities matter, browse or explicitly mark the claim as unverified. Read `references/research-protocol.md` first.

## Scoring

Use `references/scoring-rubric.md` whenever producing a scorecard. If evidence is thin, score conservatively and explain what evidence would change the score.

## Startup Type Lens

When the type is clear, apply the matching lens from `references/startup-types.md`: B2B SaaS, consumer, marketplace, devtool, AI workflow tool, agency/service, regulated, hardware, or local/service business.

## Deep Mode

When the user asks for `deep`, `brutal`, `full report`, `investor memo`, `be extremely honest`, or detailed planning, expand with:

- assumption ledger
- disconfirming evidence to seek
- customer discovery questions
- competitor and alternative map
- first customer channels
- validation sprint
- MVP cuts
- pivot paths

Keep the writing direct. Do not add theatrics or empty encouragement.

## Resources

- `references/playbooks.md`: mode-specific workflows and output shapes.
- `references/scoring-rubric.md`: score definitions and evidence requirements.
- `references/research-protocol.md`: browsing and competitor research rules.
- `references/startup-types.md`: type-specific risk lenses.
