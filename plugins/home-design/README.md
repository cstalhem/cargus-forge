# Home Design

Plan colors, lighting, furniture layout, decor and outdoor spaces for your home, with sourced reference material on standards, rules of thumb and style.

## Skills

- `color`: colour schemes, proportions and light direction for a room, and paint: LRV, sheen, scrub class and wet rooms.
- `decor`: style and decoration advice (styles, styling objects, curtains, textiles, art and indoor plants), with style choices given as options.
- `furniture-layout`: where to place furniture and what size to choose, with clearances, layouts by room type and sizes for beds, tables, rugs and art, in centimetres.
- `lighting`: light levels in lux, light sources by lumen, Kelvin and Ra, layers of general, task and mood light, and wet-room IP zones and electrical safety.
- `outdoor`: balconies, patios and gardens, with plants suited to your growing zone (odlingszon), outdoor lighting, and outdoor furniture and materials.

## Guideline strength

Every guideline in a reference file carries one of three tags, so you can tell a requirement from a habit and a habit from a matter of taste:

| Tag | What it marks | Source |
|---|---|---|
| `standard` | A standard, regulation or ergonomic measure, such as a lux level for a task or a clearance around a bed. | Always cited. |
| `convention` | A designer's rule of thumb, such as the 60-30-10 colour split or hanging art at eye height. | Cited where possible. |
| `taste` | A style choice. The skills give these as options to choose from, never as a single right answer. | Optional. |

## Reference files

Each skill keeps its facts in a `references/` folder and reads a file only when the question needs it. The skill's `SKILL.md` holds the procedure and lists its reference files, with one line on when to read each. Every reference file has the same shape:

```
# <Topic>
## <Section>
- [standard] <guideline> [1]
- [convention] <guideline> [2]
- [taste] <option>; <option>
## Sources
1. <title>, <publisher>, <url>
```

Each `standard` guideline cites a numbered source, and the file ends with a `## Sources` section that lists them.

## Scope

- **Sweden.** Advice assumes a Swedish home: metric units, Swedish growing zones (odlingszoner 1 to 8), Swedish electrical and building rules (Elsäkerhetsverket, BBR) and Nordic daylight. It is not adapted to other regions.
- **Language.** The plugin's files are in English. The skills answer in the language you write in.
- **Professional work.** For fixed electrical, structural or plumbing work, the skills tell you to hire a professional, such as an authorised electrician for fixed electrical installations, and give no DIY steps.
- **Output.** Advice goes in the chat. A room plan is written to a markdown file only when you ask, at the path you give. No images, renders, product search or prices.
