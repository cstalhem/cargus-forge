---
name: decor
description: Advise on interior style and decoration for a Swedish home, from sourced reference files. Covers choosing or blending a style, styling objects, curtains, cushions and upholstery fabric, arranging art, and choosing and caring for indoor plants. Gives style choices as options to choose from, never as one right answer.
when_to_use: When the user asks about interior style, decor or decorating, which style suits a room, styling a shelf or table, curtains or blinds, cushions, throws or upholstery fabric, hanging or arranging art, or choosing and caring for indoor plants. Also when room-plan loads it for the decor part of a room plan.
---

# Decor

Answer style and decoration questions from the reference files below. Every guideline in them carries a guideline strength tag, `standard`, `convention` or `taste`, and the tag sets how you give it.

## Procedure

1. **Gather the facts.** Use the room brief if `room-plan` passed one. Otherwise take what the user has said and ask only for the facts the question needs:
   - the room and what it is used for;
   - the pieces the user keeps, and the floor and walls as they are;
   - the style the user likes, or rooms and pictures they like;
   - who lives there: small children, cats or dogs (plants, cords and candles depend on it);
   - for plants: which way the windows face and how far into the room the plant will stand.
   If the user attaches a photo, use what it shows: style cues, existing pieces, colours, light.
2. **Read the reference files the question needs**, and only those:
   - `${CLAUDE_SKILL_DIR}/references/styles.md`: when the user asks which style to choose, what defines a style, how to blend two, or how to style objects on a shelf or table.
   - `${CLAUDE_SKILL_DIR}/references/textiles-and-art.md`: when the question is about curtains, blinds, cushions, throws, upholstery fabric, rugs as decor, candles near textiles, or arranging art on a wall.
   - `${CLAUDE_SKILL_DIR}/references/indoor-plants.md`: when the question is about choosing, placing or caring for indoor plants, or plants in a home with children or pets.
3. **Answer by guideline strength.**
   - `standard`: give it as a requirement, and name its source (the standard or the authority).
   - `convention`: give it as a rule of thumb with its numbers, and say that it can be broken for a reason.
   - `taste`: give two to four options to choose from. For each, say what it looks like and what it suits in this room. Never present one option as the right answer. If the user asks you to pick, tie the pick to what they said they like, and say it is a preference.
4. **Give safety first.** With small children or pets in the home, give the safety guidelines on plant toxicity, blind cords and candles before any style advice they affect.
5. **Hand off what belongs to another skill.** Colour schemes and paint go to `color`. Lamps, lux and Kelvin go to `lighting`. Furniture placement, rug sizes and the height to hang art go to `furniture-layout`. Gardens, patios and balconies go to `outdoor`. Name the skill, or load it when the user wants that part answered too.
6. **Send fixed work to a professional.** If the advice needs fixed electrical, structural or plumbing work, such as wiring a wall lamp, adding a ceiling outlet or moving a radiator, say to hire a professional (an authorised electrician for fixed electrical installations), and give no DIY steps.

Answer in the language the user writes in, in metric units.
