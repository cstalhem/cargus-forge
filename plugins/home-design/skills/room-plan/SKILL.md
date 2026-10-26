---
name: room-plan
description: Plan one room or outdoor area in a Swedish home from start to finish. Builds a room brief from the user's description, measurements and photos, asks only for the facts it lacks, loads the home-design skills the space needs (color, lighting, furniture-layout, decor, outdoor) and gives one plan that covers them, with each guideline's strength. Writes the plan to a markdown file only when asked, at the path the user gives.
when_to_use: When the user asks for a plan, a makeover or a redesign of a whole room or outdoor area, such as "plan my living room", "help me furnish the bedroom", "how should I do up this balcony", or attaches a photo of a room and asks what to do with it. Also when a question spans more than one of colour, lighting, furniture, decor and outdoor for the same space. For a question about one of those alone, the domain skill answers it directly.
---

# room-plan

Give the user one plan for one room or outdoor area. First build a room brief, then load the domain skills the space needs, then join their advice into one plan. Answer in the language the user writes in, in metric units.

## 1. Build the room brief

The room brief holds the facts about the space that the plan rests on. Fill each field from the user's message, earlier messages and any photo:

| Field | What to record |
|---|---|
| Space | The room or outdoor area, and what it is used for and by whom (children, pets, an older person). |
| Size | Floor area in m², length and width in cm, and ceiling height. |
| Orientation and windows | Which way the windows face, how many and how large, and where the doors are and which way they swing. |
| Existing pieces | Furniture, fixed joinery, floor, lamps and plants that stay, with their sizes and colours. |
| Budget | Roughly how much the user will spend, or whether to work with what is there. |
| Style | The style the user wants, or rooms and pictures they like. |
| Photos | What each attached photo shows. |
| Growing zone | Outdoor areas only: the odlingszon, I to VIII. |

- **Photos.** When the user attaches a photo of the room, look at it before you ask anything. Take from it what it shows: the layout, windows and doors, the existing pieces, the colours of walls, floor and furniture, the light, and style cues. Put each of these in the room brief, and say what you read from the photo. A photo gives no exact measures: mark a size you estimate from it as an estimate, and ask the user to confirm it if the plan depends on it.
- **Ask only for what is missing.** Ask for a fact only when the plan needs it and neither the user nor a photo gave it, in one round of questions. Do not ask for a field the plan does not need, such as the growing zone for an indoor room. If the user does not know a fact, go on without it, and say which advice it would change.
- **Show the brief.** Before the plan, show the room brief in a few lines, so the user can correct it.

## 2. Load the domain skills the space needs

Decide which parts of the plan the user wants and the space needs, then load each of those skills with the Skill tool, by its full name, and pass it the room brief. Each skill reads its own reference files.

| Skill | Load it when the plan covers |
|---|---|
| `home-design:color` | wall colours, colour schemes or paint |
| `home-design:lighting` | lamps, light levels or electrical points indoors |
| `home-design:furniture-layout` | where furniture goes, clearances, or the size of furniture, rugs and art |
| `home-design:decor` | style, textiles, curtains, art arrangement or indoor plants |
| `home-design:outdoor` | a garden, patio, terrace or balcony: plants, outdoor lighting or outdoor furniture |

- A whole indoor room usually needs `color`, `lighting`, `furniture-layout` and `decor`. Leave out a skill when the user has said that part is settled, or when it does not apply.
- An outdoor area needs `outdoor`, which covers its plants, lighting and furniture. Add `decor` only for textiles or styling on a covered balcony or terrace. Façade and trim colours are out of scope.
- Load a skill once per plan, not once per question.

## 3. Give one plan

Join what the skills give into one plan for the space, not one answer per skill:

1. **Room brief**, as in step 1.
2. **Plan**, by part: layout first, because colour, light and decor depend on where things go; then colour, lighting and decor; for an outdoor area, layout, plants, lighting and furniture.
3. **Make the parts agree.** Check that the parts fit one another: lights where the furniture puts the reading chair and the dining table, colours that suit the room's orientation and the chosen lamps' Kelvin, and textiles and art in the chosen colours and style. Where two skills pull different ways, say so and give the user the choice.
4. **Keep each guideline's strength.** Keep the `standard`, `convention` or `taste` tag that each skill gives, and the source of each `standard` guideline. Give `taste` as options to choose from, never as one right answer.
5. **Next steps**, in the order to do them, with what needs a professional marked.

Budget sets what the plan keeps, changes and adds first. Give no prices, product names or shop searches.

## Professional work

When the plan needs fixed electrical, structural or plumbing work, such as a new ceiling outlet, a moved switch or light point, wiring a wall lamp, removing or moving a wall, a balcony's load, or moving a sink, radiator or appliance to a new connection:

- Say that the user must hire a professional for that part: an authorised electrician (an electrical installation company registered with Elsäkerhetsverket) for fixed electrical installations, and a builder, plumber or structural engineer for the rest.
- Give no DIY steps for that work: no wiring, no connection order, no tools and no how-to.
- Offer an option that needs no fixed work where one fits, such as a plug-in lamp in place of a new ceiling point.

## Saving the plan

- Give the plan in the chat. Write no file unless the user asks to save the plan.
- When the user asks to save it, write the plan as markdown to the path the user gives. If they ask to save it but give no path, ask for the path. Do not pick one yourself.
- If a file already exists at that path, ask before you overwrite it.
- After writing, say the path you wrote to.
