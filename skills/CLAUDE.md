# Skill Conventions

## File Format

Each skill is a directory containing a `SKILL.md` file:

```
skills/<stack>/<skill-name>/SKILL.md
```

The directory name is the skill identifier (lowercase-kebab-case).

## Required Frontmatter

```yaml
---
name: skill-name # Must match parent directory name
description: Technology — coverage list in comma-separated phrases.
---
```

**name** — Matches the directory name exactly (e.g., `react` for `skills/frontend/react/`)

**description** — Format: `"<Technology> — <what it covers>"`. Examples:

- `"React core patterns — components, hooks, TypeScript integration, state management, performance, and error handling."`
- `"Neo4j Cypher — query patterns, performance optimization, fraud-domain queries, and Neo4j 5+ features."`

## Body Sections

### Required for All Skills

**H1 Title** — The technology name (e.g., `# React`, `# Tailwind`)

**## When to Use** — Three things:

1. What this skill covers
2. What to defer to other skills (with cross-references by name)
3. Version/target info if applicable

Cross-reference format:

```markdown
Defer to other skills for:

- **shadcn-ui skill**: Component library APIs, form integration
- **tailwind skill**: CSS utility patterns and styling conventions
```

### Required for Complete Skills (>50 lines)

**Pattern sections** (## numbered or named) — The bulk of the document. Organized by concept area. Each section contains:

- Explanation of the pattern
- Code examples in fenced blocks with correct language tags (`tsx`, `python`, `cypher`, etc.)
- Configuration or type definitions where relevant

**Anti-Patterns** — Table format at the end of the document or inline within sections:

```markdown
| Anti-Pattern          | Why It Fails          | Fix                 |
| --------------------- | --------------------- | ------------------- |
| Concrete bad practice | Specific failure mode | Specific correction |
```

Minimum 5 anti-patterns per complete skill.

## Quality Standards

### Complete Skill (400–900 lines)

- All sections above are present and substantive
- Code examples are copy-pasteable (not pseudocode)
- Fenced code blocks use correct language tags
- Version-specific info is noted (e.g., "React 19+", "Tailwind v4")
- Anti-patterns include concrete "Why It Fails" explanations
- Cross-references use exact skill names

### Stub Skill (18 lines)

Has only frontmatter, H1, "When to Use", and `[TODO]` placeholders. Pattern:

```markdown
---
name: skill-name
description: Technology — brief coverage list.
---

# Technology Name

## When to Use

Use this skill when <scope>. Covers <topic list>.

## Patterns

[TODO: Add patterns]

## Anti-Patterns

[TODO: Add anti-patterns]

## Examples

[TODO: Add examples]
```

## Directory Placement

| Directory   | When to use           | Example skills                                |
| ----------- | --------------------- | --------------------------------------------- |
| `global/`   | Stack-independent     | neo4j-cypher, neo4j-data-models, git-workflow |
| `frontend/` | Frontend technologies | react, shadcn-ui, tailwind, zustand-state     |
| `python/`   | Python technologies   | fastapi, testing-pytest                       |
| `rust/`     | Rust technologies     | testing-rust, neo4j-driver-rust               |

## Reference Skills

Use these as structural templates when writing new skills:

- **Best complete skill**: `frontend/react/SKILL.md` (940 lines) — full section structure, extensive code examples, anti-patterns table
- **Concise complete skill**: `global/neo4j-data-models/SKILL.md` (428 lines) — focused scope, clear patterns
- **Stub template**: `python/fastapi/SKILL.md` (18 lines) — minimal valid structure
