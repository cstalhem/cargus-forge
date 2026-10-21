---
title: "Air-source heat pump performance in cold climates"
slug: "cold-climate-performance"
agent: researcher
model: sonnet
created: "2026-10-01T09:00:00+02:00"
updated: "2026-10-01T11:00:00+02:00"
status: "complete"
confidence: "medium"
tags: [heat-pumps, efficiency]
---

# Air-source heat pump performance in cold climates

## Assignment

**Task as delegated:**
> Fixture for the research plugin's tests. Find how well air-source heat pumps heat homes in cold winters.

**Complementary information received:** None.

**Scope:** Efficiency below freezing and the need for backup heat.

**Out of scope:** Ground-source systems.

## Summary

- Air-source heat pump efficiency falls as the outdoor temperature drops [S2].
- Units built for cold climates still deliver at least 1.75 units of heat per unit of electricity at -15 °C [S1] (single source).
- In very cold spells some systems fall back on resistance heat, which reduces the seasonal saving [S2].

## Findings

### Efficiency below freezing

The colder the outdoor air, the less heat a heat pump can move per unit of electricity [S2]. Newer cold-climate units are now a practical option in cold regions [S2]. The NEEP cold-climate specification requires a coefficient of performance of at least 1.75 at 5 °F (-15 °C) [S1] (single source). That is still well above the 1.0 of resistance heating.

### Backup heat

Some systems use supplementary resistance heat when the heat pump cannot meet the load in very cold weather [S2]. The more hours that backup runs, the closer the seasonal running cost gets to resistance heating.

### Use in cold countries

Heat pumps already heat a large share of buildings in the Nordic countries, which have long, cold winters [S3] (single source).

## Conflicting or uncertain information

None found. The specification sets a minimum; it does not say how often real installations meet it in the field.

## Sources

| ID | Title | Author / publisher | Type | Published / updated | Accessed | URL | Reliability |
|---|---|---|---|---|---|---|---|
| S1 | Cold Climate Air Source Heat Pump Specification and Product List | Northeast Energy Efficiency Partnerships (NEEP) | spec | unknown | 2026-10-01 | https://neep.org/heating-electrification/ccashp-specification-product-list | high |
| S2 | Air-Source Heat Pumps | US Department of Energy, Energy Saver | official docs | unknown | 2026-10-01 | https://www.energy.gov/energysaver/air-source-heat-pumps | high |
| S3 | The Future of Heat Pumps | International Energy Agency | paper | 2022-11-30 | 2026-10-01 | https://www.iea.org/reports/the-future-of-heat-pumps | high |

## Comments

The specification is a minimum for listed products, not a field result. No field study was reviewed.

## Decisions made

- Treated -15 °C as the reference point for a cold winter, as the specification does.

## Recommended follow-up research

- Field data on how many hours backup heat runs in a cold winter.

## Change log

- 2026-10-01: Fixture created.
