---
name: build-and-price-config
description: Create safe SQL edit files for IJACK Build & Price configuration changes. Use this skill whenever the user asks to add, replace, remove, map, group, or make available pump tops, power units, rods, barrels, voltages, ambients, documents, options, or any build_* / Build and Price configurator data. This skill should trigger for requests like “replace 050-0398 with 050-0500 in B&P”, “add this option to these pump tops”, “make these rods available”, “add build and price configuration”, or “update the configurator,” even if the user does not mention SQL.
tags:
  - sql
  - postgres
  - build-and-price
  - configuration
  - parts
---

# Build & Price Configuration SQL Skill

Use this skill to inspect current Build & Price data and generate a reviewable SQL file for the user to run manually. Do not apply the edit yourself.

## Core outcome

Write a SQL file in the current workspace's temporary filesystem:

```text
/tmp/build-and-price-edit-YYYYMMDD-HHMM.sql
```

The file must describe the requested change, show current-state checks, contain transactional SQL, and include post-change verification queries. Leave `COMMIT;` commented out and keep `ROLLBACK;` active by default so the user can decide when and where to run it.

## Database access rule

Use only the configured `mcp-postgres` MCP server to inspect database data and schemas. Do not ask the user which database environment to use. Use the active MCP PostgreSQL context exactly as configured.

Use database inspection for:

- current published preview,
- affected `build_*` table schemas,
- relevant rows in B&P tables,
- relevant rows in `parts`,
- existing direct/group/all applicability patterns,
- constraints and uniqueness rules when inserting or updating rows.

Never use `psql`, Python SQL scripts, or direct application database connections for inspection.

## Required workflow

1. Restate the requested B&P change in plain language.
2. Identify affected concepts: pump top, power unit, rod, barrel, voltage, ambient, document, pump-top option, power-unit option, group, structure group, or mapping.
3. Inspect current data with `mcp-postgres` before drafting SQL.
4. Resolve all user-provided part numbers to `parts.id` using the latest revision rule.
5. Determine whether the edit belongs in item tables, group tables, mapping/applicability tables, or a combination.
6. Decide whether direct mapping, group mapping, structure mapping, or `all` is appropriate.
7. Write `/tmp/build-and-price-edit-YYYYMMDD-HHMM.sql`.
8. Tell the user the path and summarize assumptions, affected tables, and manual review points.

## Important table model

Build & Price is rooted at `build_preview`. All configuration rows belong to a preview. The live customer configurator uses the row where `build_preview.published_ind = true`.

### Item tables reference `parts.id`

These tables point directly at `parts.id`:

| Concept | Table | Part FK column |
|---|---|---|
| Pump top | `build_pump_top` | `pump_top_id` |
| Power unit | `build_power_unit` | `power_unit_id` |
| Rod | `build_rod` | `rod_id` |
| Barrel | `build_barrel` | `barrel_id` |
| Site voltage | `build_site_voltage` | `site_voltage_id` |
| Site ambient | `build_site_ambient` | `site_ambient_id` |
| Pump-top option | `build_pump_top_option` | `pump_top_option_id` |
| Power-unit option | `build_power_unit_option` | `power_unit_option_id` |
| Document | `build_document` | `document_id` |

### Mapping tables reference build-table row IDs

Group and applicability tables usually reference `build_*` primary keys, not raw `parts.id`. For example:

- `build_pump_top_group_pump_top.pump_top_id` → `build_pump_top.id`
- `build_power_unit_group_power_unit.power_unit_id` → `build_power_unit.id`
- `build_pump_top_group_option.pump_top_option_id` → `build_pump_top_option.id`
- `build_power_unit_group_option.power_unit_option_id` → `build_power_unit_option.id`

Be explicit about which ID space is being used in all SQL and comments.

## Build tables to consider

When planning a B&P configuration edit, consider all relevant tables, including:

- `build_barrel`
- `build_document`
- `build_document_mapping`
- `build_power_unit`
- `build_power_unit_group`
- `build_power_unit_group_option`
- `build_power_unit_group_power_unit`
- `build_power_unit_option`
- `build_power_unit_option_group`
- `build_preview`
- `build_pump_top_group`
- `build_pump_top_group_barrel`
- `build_pump_top_group_option`
- `build_pump_top_group_power_unit`
- `build_pump_top_group_pump_top`
- `build_pump_top_group_rod`
- `build_pump_top_option`
- `build_pump_top_option_group`
- `build_pump_top`
- `build_rod`
- `build_site_ambient`
- `build_site_voltage`
- `build_site_voltage_frequency`
- `build_structure_group`

If the exact table name differs in the live schema, trust `mcp-postgres` schema inspection over memory.

## Latest revision part lookup

Users usually provide part numbers like `050-0398`, not `parts.id`. Resolve those to the latest active revision by default.

Use the generated `parts.part_name` and `parts.part_rev` fields. `part_name` is the base part number without a trailing revision suffix such as `r2`; `part_rev` is the numeric revision. Unless the user explicitly says to use an exact revision, select the non-deleted row with the highest `part_rev`.

Preferred SQL pattern:

```sql
WITH requested_part AS (
  SELECT id, part_num, part_name, part_rev, description
  FROM parts
  WHERE part_name = regexp_replace(:requested_part_num, 'r\d+$', '')
    AND flagged_for_deletion = false
  ORDER BY part_rev DESC
  LIMIT 1
)
SELECT * FROM requested_part;
```

If the user explicitly asks for an exact revision, match `parts.part_num` exactly and call that assumption out in the SQL header.

## Applicability decision rules

B&P applicability can be direct, group-based, structure-based, or universal. Pick the simplest model that matches the business intent and existing data pattern.

### Prefer direct mapping for one-off changes

Use direct applicability when a part applies to one or a small number of specific pump tops or power units:

- `build_pump_top_group_option.applies_to = 'pump_top'`
- `build_power_unit_group_option.applies_to = 'power_unit'`
- `build_pump_top_group_rod.applies_to = 'pump_top'`
- `build_pump_top_group_barrel.applies_to = 'pump_top'`

This is often simplest and mirrors many existing B&P option rows.

### Prefer groups for repeated patterns

Use a pump top or power unit group when the same applicability applies across many rows and the grouping has a clear reusable meaning, such as a family of pump tops sharing the same rod set.

Before creating a group:

1. Search for an existing suitable group.
2. Verify group membership.
3. Add missing members only if the group name and membership remain coherent.
4. Create a new group only when no existing group expresses the intended set.

### Use structure mappings for PT × PU-specific rules

Use `build_structure_group` when applicability depends on a pump-top and power-unit combination, not either one independently.

### Use `all` sparingly

Use `applies_to = 'all'` only when the part or option is truly available for every relevant pump top or power unit in the preview. Confirm with the user if the request is ambiguous and the edit would make something universal.

## SQL file format

Every generated file should follow this structure:

```sql
-- Build & Price edit
-- Generated: YYYY-MM-DD HH:MM UTC
-- Requested change: ...
-- MCP source: mcp-postgres active configured database context
-- Preview scope: published preview unless noted otherwise
-- Assumptions:
--   - part numbers resolve to latest non-deleted revision by part_name + max(part_rev)
--   - user will review and run manually
-- Affected tables:
--   - ...

BEGIN;

-- 1. Pre-check: published preview
SELECT preview_id, name, published_ind
FROM build_preview
WHERE published_ind = true;

-- 2. Pre-check: part resolution
-- Include old/new/input part lookups here.

-- 3. Pre-check: current affected B&P rows
-- Include SELECTs that show existing rows before DML.

-- 4. Edit statements
-- INSERT/UPDATE/DELETE statements go here.

-- 5. Post-check: expected rows after edit
-- Include SELECTs proving the requested state.

-- COMMIT;
ROLLBACK;
```

Use CTEs for part resolution so the SQL is readable and repeatable. Prefer idempotent inserts guarded by `WHERE NOT EXISTS` or `ON CONFLICT DO NOTHING` when uniqueness constraints allow it.

## Example: replace a part in an item table

Request: “Anywhere `050-0398` is used as a pump-top option in B&P, replace it with `050-0500`.”

```sql
BEGIN;

WITH published_preview AS (
  SELECT preview_id
  FROM build_preview
  WHERE published_ind = true
),
old_part AS (
  SELECT id, part_num, part_name, part_rev
  FROM parts
  WHERE part_name = regexp_replace('050-0398', 'r\d+$', '')
    AND flagged_for_deletion = false
  ORDER BY part_rev DESC
  LIMIT 1
),
new_part AS (
  SELECT id, part_num, part_name, part_rev
  FROM parts
  WHERE part_name = regexp_replace('050-0500', 'r\d+$', '')
    AND flagged_for_deletion = false
  ORDER BY part_rev DESC
  LIMIT 1
)
SELECT 'pre-check matching pump_top_option rows' AS check_name,
       bpto.id,
       p.part_num,
       p.description
FROM build_pump_top_option bpto
JOIN parts p ON p.id = bpto.pump_top_option_id
JOIN published_preview pp ON pp.preview_id = bpto.preview_id
WHERE bpto.pump_top_option_id = (SELECT id FROM old_part);

WITH published_preview AS (
  SELECT preview_id
  FROM build_preview
  WHERE published_ind = true
),
old_part AS (
  SELECT id
  FROM parts
  WHERE part_name = regexp_replace('050-0398', 'r\d+$', '')
    AND flagged_for_deletion = false
  ORDER BY part_rev DESC
  LIMIT 1
),
new_part AS (
  SELECT id
  FROM parts
  WHERE part_name = regexp_replace('050-0500', 'r\d+$', '')
    AND flagged_for_deletion = false
  ORDER BY part_rev DESC
  LIMIT 1
)
UPDATE build_pump_top_option bpto
SET pump_top_option_id = (SELECT id FROM new_part),
    timestamp_utc_updated = now()
FROM published_preview pp
WHERE bpto.preview_id = pp.preview_id
  AND bpto.pump_top_option_id = (SELECT id FROM old_part);

-- COMMIT;
ROLLBACK;
```

Adapt this pattern to the relevant item table. If replacing a pump top, power unit, rod, barrel, voltage, ambient, or document, inspect dependent mapping rows first and preserve build-table IDs where possible.

## Example: add a pump-top option directly to one pump top

Use this pattern when the option should apply to one pump top and there is no reusable group pattern.

```sql
WITH published_preview AS (...),
option_part AS (... latest part lookup ...),
target_pump_top_part AS (... latest part lookup ...),
option_row AS (
  INSERT INTO build_pump_top_option (pump_top_option_id, preview_id, timestamp_utc_inserted, timestamp_utc_updated)
  SELECT option_part.id, published_preview.preview_id, now(), now()
  FROM option_part, published_preview
  WHERE NOT EXISTS (
    SELECT 1
    FROM build_pump_top_option existing
    WHERE existing.preview_id = published_preview.preview_id
      AND existing.pump_top_option_id = option_part.id
  )
  RETURNING id, preview_id
),
resolved_option_row AS (
  SELECT id, preview_id FROM option_row
  UNION ALL
  SELECT bpto.id, bpto.preview_id
  FROM build_pump_top_option bpto, option_part, published_preview
  WHERE bpto.preview_id = published_preview.preview_id
    AND bpto.pump_top_option_id = option_part.id
),
target_pump_top AS (
  SELECT bpt.id, bpt.preview_id
  FROM build_pump_top bpt, target_pump_top_part, published_preview
  WHERE bpt.preview_id = published_preview.preview_id
    AND bpt.pump_top_id = target_pump_top_part.id
)
INSERT INTO build_pump_top_group_option (
  pump_top_option_id,
  applies_to,
  pump_top_id,
  is_default,
  preview_id,
  timestamp_utc_inserted,
  timestamp_utc_updated
)
SELECT resolved_option_row.id,
       'pump_top',
       target_pump_top.id,
       false,
       published_preview.preview_id,
       now(),
       now()
FROM resolved_option_row, target_pump_top, published_preview
WHERE NOT EXISTS (
  SELECT 1
  FROM build_pump_top_group_option existing
  WHERE existing.preview_id = published_preview.preview_id
    AND existing.pump_top_option_id = resolved_option_row.id
    AND existing.applies_to = 'pump_top'
    AND existing.pump_top_id = target_pump_top.id
);
```

## Example: group rods or barrels across multiple pump tops

When the same rod or barrel set applies to many pump tops, look for an existing pump-top group first. If none fits, create a clearly named `build_pump_top_group`, add pump tops through `build_pump_top_group_pump_top`, then map rods/barrels with `applies_to = 'group'`.

Keep these distinctions clear:

- `build_rod.rod_id` / `build_barrel.barrel_id` → `parts.id`
- `build_pump_top_group_rod.rod_id` → `build_rod.id`
- `build_pump_top_group_barrel.barrel_id` → `build_barrel.id`
- `build_pump_top_group_rod.pump_top_group_id` → `build_pump_top_group.pump_top_group_id`

## Final response format

After generating the SQL file, respond with:

```text
Created: /tmp/build-and-price-edit-YYYYMMDD-HHMM.sql

Summary:
- Requested change: ...
- Inspected with: mcp-postgres
- Preview scope: ...
- Affected tables: ...
- Part resolution: ...
- Manual review points: ...
```

Do not paste the entire SQL file unless the user asks. Keep the SQL in `/tmp` for manual execution.
