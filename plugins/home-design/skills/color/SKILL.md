---
name: color
description: Advise on colours for a room in a Swedish home, from colour schemes, proportions and light direction to paint (LRV, sheen, scrub class and wet rooms), drawn from sourced reference files, with each recommendation's guideline strength.
when_to_use: When the user asks which colours to use in a room, how to combine colours, which white to pick, what LRV or sheen (glansgrad) a paint should have, how a north- or south-facing room changes a colour, or what paint a bathroom wall needs. Also when room-plan loads it for a room's colours.
---

# color

Answer colour questions for a Swedish home from this skill's reference files, and give each recommendation its guideline strength.

## Reference files

The files are in this skill's `references/` folder. Read a file only when the question needs it.

- `references/color-theory.md`: NCS codes, colour schemes, the 60-30-10 split, warm and cool, light and dark, light direction, testing a colour, and contrast for low vision. Read it for any question about which colours to use or combine.
- `references/paint.md`: LRV, sheen (glansgrad), scrub resistance, how much paint to buy, and painting in wet rooms. Read it when the question is about the paint itself, or when your answer names an LRV or a sheen.

## Procedure

1. **Room facts.** If `room-plan` passed a room brief, use it. Otherwise take from the message and any photo: the room and what it is used for, which way its windows face, how much daylight it gets, the colours that stay (floor, large furniture, fixed joinery), and the style the user wants. Ask only for the facts your answer needs and lacks, in one round of questions. From a photo, read the existing colours and the light, and say what you read.
2. **Read** the reference files that the question needs.
3. **Advise** from the references:
   - Tag each recommendation with its guideline strength: `standard`, `convention` or `taste`.
   - Cite the source of each `standard` recommendation, by its title in the file's `## Sources`, and of each `convention` the file cites.
   - Give `taste` as two or three options, each with what it does in this room, never as the one right answer.
   - Give a specific colour as an NCS code. For a paint's own LRV or NCS code, send the user to the maker's colour chart; do not make one up.
   - Advice that the references do not hold: say it is general knowledge, and tag it no higher than `convention`.
4. **Test.** End a colour choice with how to test it in the room, from `color-theory.md`.

## Limits

- Painting in a bathroom's or laundry room's wet zones is waterproofing work. Name the wet zone and the system class from `paint.md`, refer the work to an MVK-authorised painting company, and give no DIY steps. Do the same for fixed electrical, structural or plumbing work: say to hire a professional.
- No façade or exterior trim colours.
- Answer in the language the user writes in, with metric units.
