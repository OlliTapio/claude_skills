---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
license: Complete terms in LICENSE.txt
---

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

The user provides frontend requirements: a component, page, application, or interface to build. They may include context about the purpose, audience, or technical constraints.

## Design Thinking

Before coding, commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this solve? Who uses it?
- **Tone**: Pick a clear direction — brutally minimal, maximalist, retro-futuristic, organic, luxury, playful, editorial, brutalist, art deco, soft/pastel, industrial, etc.
- **Differentiation**: What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute with precision. Bold maximalism and refined minimalism both work — the key is intentionality.

Then implement working code (HTML/CSS/JS, React, Vue, etc.) that is production-grade, visually striking, cohesive, and meticulously refined.

## Aesthetic Guidelines

- **Typography**: Distinctive, characterful font choices. Pair a display font with a refined body font. Avoid generic defaults (Inter, Roboto, Arial, system fonts).
- **Color & Theme**: Cohesive palette via CSS variables. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
- **Motion**: CSS-only or Motion library. Focus on high-impact moments: one orchestrated page load with staggered reveals beats scattered micro-interactions. Surprise with scroll-triggers and hover states.
- **Spatial Composition**: Unexpected layouts. Asymmetry, overlap, diagonal flow, grid-breaking. Generous negative space OR controlled density.
- **Backgrounds & Details**: Atmosphere over solid colors. Gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, grain overlays.

## Anti-Patterns (never do these)

- Inter/Roboto/Arial as the primary font
- Purple gradients on white backgrounds
- Predictable symmetric card grids
- Cookie-cutter component layouts from UI libraries
- Same aesthetic across different generations — every design should feel unique

## Example Directions

**Brutalist editorial** — Tight monospace stack (JetBrains Mono + Space Mono), stark black/white with one fluorescent accent (#39FF14), oversized bold headlines, hard borders, no rounded corners, generous whitespace as a design element.

**Warm organic** — Libre Baskerville + DM Sans, muted earth palette (terracotta #C67A4B, sage #87A878, cream #F5F0E8), soft blob shapes as backgrounds, subtle parallax on scroll, rounded containers with grain texture overlays.

**Neo-deco luxury** — Playfair Display + Outfit, deep navy (#0A1628) and gold (#C9A96E), geometric border patterns, thin decorative rules, letter-spaced uppercase labels, entrance animations with cubic-bezier easing.

Match implementation complexity to the vision. Maximalist designs need elaborate animation code. Minimalist designs need restraint and precision in spacing and typography.
