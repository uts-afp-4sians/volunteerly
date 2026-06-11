"""unify categories and interests into 11 shared causes

Revision ID: b8c9d0e1f2a3
Revises: a7b8c9d0e1f2
Create Date: 2026-06-11 12:00:00.000000

Data-only migration (no DDL). Collapses the legacy split taxonomy — 8 program
categories + up to 22 keywords (3 program tags + 19 profile interests) — into ONE
canonical set of 11 causes that serve as both categories and interests, with a
1:1 keyword per category (matching id and name):

    1 Nature  2 Animals  3 Education  4 Arts  5 Food  6 Wellbeing
    7 Elderly  8 Kids  9 Disability  10 Sports  11 Community

Every existing FK is repointed by *meaning*, keyed on the legacy integer id (which
encodes the old meaning regardless of the row's current name), so no program loses
its true category and no user loses their interests. Collisions created by the
many-to-one remap (e.g. old "Health" + "Mental Health" → "Wellbeing") are deduped.

ASSUMPTION: the database holds the pre-unification taxonomy. Alembic runs this
exactly once, on the upgrade from a7b8c9d0e1f2, so that holds. It no-ops on an
empty `categories` table (a fresh DB), leaving greenfield seeding to scripts/seed.py.
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b8c9d0e1f2a3"
down_revision: str | None = "a7b8c9d0e1f2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


# The 11 unified causes (id is identical for category and keyword).
TAXONOMY: list[tuple[int, str]] = [
    (1, "Nature"),
    (2, "Animals"),
    (3, "Education"),
    (4, "Arts"),
    (5, "Food"),
    (6, "Wellbeing"),
    (7, "Elderly"),
    (8, "Kids"),
    (9, "Disability"),
    (10, "Sports"),
    (11, "Community"),
]

# Legacy category id -> new category id (by old meaning).
#   1 Environment  2 Community  3 Education  4 Health
#   5 Animals      6 Seniors    7 Food       8 Arts
CATEGORY_REMAP = {1: 1, 2: 11, 3: 3, 4: 6, 5: 2, 6: 7, 7: 5, 8: 4}

# Legacy keyword id -> new keyword id (by old meaning). Covers both the 12-row
# and 22-row legacy seeds; unknown ids fall through to NULL and are dropped.
#   1-3 program tags (Environment) · 4-22 profile interests
KEYWORD_REMAP = {
    1: 1, 2: 1, 3: 1,          # Tree Planting / Beach Cleanup / Recycling -> Nature
    4: 2,                       # Animal Care        -> Animals
    5: 4,                       # Arts & Creativity  -> Arts
    6: 11,                      # Community Building -> Community
    7: 3,                       # Education          -> Education
    8: 7,                       # Aged Care          -> Elderly
    9: 1,                       # Environment        -> Nature
    10: 5,                      # Food               -> Food
    11: 11,                     # Social Justice     -> Community
    12: 11,                     # Technology         -> Community
    13: 8,                      # Children & Youth   -> Kids
    14: 6,                      # Health             -> Wellbeing
    15: 6,                      # Mental Health      -> Wellbeing
    16: 9,                      # Disability Support -> Disability
    17: 11,                     # Homelessness       -> Community
    18: 3,                      # Literacy           -> Education
    19: 11,                     # Disaster Relief    -> Community
    20: 10,                     # Sports             -> Sports
    21: 4,                      # Music              -> Arts
    22: 11,                     # Refugees           -> Community
}


def _case(column: str, mapping: dict[int, int], default: str) -> str:
    """Render a SQL CASE that remaps `column` via `mapping`, else `default`."""
    whens = " ".join(f"WHEN {old} THEN {new}" for old, new in mapping.items())
    return f"CASE {column} {whens} ELSE {default} END"


def _remap_junction(table: str, entity_col: str, key_case: str) -> None:
    """Rebuild a (entity, keyword) junction with remapped, deduped keyword ids.

    A temp DISTINCT rebuild collapses rows that now collide (two old interests
    mapping to one new cause), keeping the PK valid. Rows whose keyword can't be
    mapped (CASE -> NULL) are dropped."""
    tmp = f"_remap_{table}"
    op.execute(f"DROP TABLE IF EXISTS {tmp}")
    op.execute(
        f"""
        CREATE TEMPORARY TABLE {tmp} AS
        SELECT DISTINCT {entity_col}, {key_case} AS keyword_id
        FROM {table}
        WHERE ({key_case}) IS NOT NULL
        """
    )
    op.execute(f"DELETE FROM {table}")
    op.execute(
        f"INSERT INTO {table} ({entity_col}, keyword_id) "
        f"SELECT {entity_col}, keyword_id FROM {tmp}"
    )
    op.execute(f"DROP TABLE {tmp}")


def _select_constants(rows: list[tuple[int, str]]) -> str:
    """A portable inline (id, name) table: SELECT ... UNION ALL SELECT ...

    SQLite predates the `(VALUES ...) AS t(col, ...)` column-alias syntax, so a
    UNION-ALL of named SELECTs is used instead — supported everywhere."""
    return " UNION ALL ".join(
        f"SELECT {rid} AS id, '{name}' AS name"
        if i == 0
        else f"SELECT {rid}, '{name}'"
        for i, (rid, name) in enumerate(rows)
    )


def upgrade() -> None:
    conn = op.get_bind()
    has_data = conn.execute(sa.text("SELECT COUNT(*) FROM categories")).scalar()
    if not has_data:
        # Fresh DB — scripts/seed.py owns initial taxonomy; nothing to remap.
        return

    cat_case = _case("category_id", CATEGORY_REMAP, "category_id")
    kw_case = _case("keyword_id", KEYWORD_REMAP, "NULL")

    # 1. Rename categories 1-8 to the new scheme and add 9-11. (Names only;
    #    program FKs are repointed by old integer id in step 2.)
    name_case = " ".join(f"WHEN {cid} THEN '{name}'" for cid, name in TAXONOMY)
    op.execute(
        f"UPDATE categories SET category_name = CASE category_id {name_case} "
        f"ELSE category_name END WHERE category_id BETWEEN 1 AND 11"
    )
    op.execute(
        f"INSERT INTO categories (category_id, category_name) "
        f"SELECT v.id, v.name FROM ({_select_constants(TAXONOMY)}) AS v "
        f"WHERE v.id NOT IN (SELECT category_id FROM categories)"
    )

    # 2. Repoint each program to its new category by old meaning.
    op.execute(f"UPDATE programs SET category_id = {cat_case}")

    # 3. Repoint + dedup the keyword junctions (targets 1-11 already exist).
    _remap_junction("user_interests", "user_id", kw_case)
    _remap_junction("program_keywords", "program_id", kw_case)

    # 4. Collapse keywords to the 11 causes: rename 1-11 in place (identity
    #    mapping, all is_interest), backfill any missing, drop the retired rest.
    op.execute(
        f"UPDATE keywords SET keyword_name = CASE keyword_id {name_case} "
        f"ELSE keyword_name END, category_id = keyword_id, is_interest = 1 "
        f"WHERE keyword_id BETWEEN 1 AND 11"
    )
    op.execute(
        f"INSERT INTO keywords (keyword_id, category_id, keyword_name, is_interest) "
        f"SELECT v.id, v.id, v.name, 1 FROM ({_select_constants(TAXONOMY)}) AS v "
        f"WHERE v.id NOT IN (SELECT keyword_id FROM keywords)"
    )
    op.execute("DELETE FROM keywords WHERE keyword_id > 11")


# --- Downgrade: best-effort, LOSSY. -----------------------------------------
# The unification is many-to-one, so the inverse can only restore a representative
# legacy taxonomy and repoint data to one plausible old id per cause. Programs and
# interests that were merged (e.g. Health + Mental Health -> Wellbeing) cannot be
# split back apart. Restores the pre-change 8-category / 22-keyword seed shape.

# New category id -> representative legacy category id.
CATEGORY_REMAP_DOWN = {1: 1, 2: 5, 3: 3, 4: 8, 5: 7, 6: 4, 7: 6, 8: 2, 9: 2, 10: 2, 11: 2}
# New keyword id -> representative legacy interest keyword id.
KEYWORD_REMAP_DOWN = {1: 9, 2: 4, 3: 7, 4: 5, 5: 10, 6: 14, 7: 8, 8: 13, 9: 16, 10: 20, 11: 6}

LEGACY_CATEGORIES: list[tuple[int, str]] = [
    (1, "Environment"), (2, "Community"), (3, "Education"), (4, "Health"),
    (5, "Animals"), (6, "Seniors"), (7, "Food"), (8, "Arts"),
]
# (keyword_id, category_id, name, is_interest) — the pre-change seed catalog.
LEGACY_KEYWORDS: list[tuple[int, int, str, int]] = [
    (1, 1, "Tree Planting", 0), (2, 1, "Beach Cleanup", 0), (3, 1, "Recycling", 0),
    (4, 5, "Animal Care", 1), (5, 8, "Arts & Creativity", 1),
    (6, 2, "Community Building", 1), (7, 3, "Education", 1), (8, 6, "Aged Care", 1),
    (9, 1, "Environment", 1), (10, 7, "Food", 1), (11, 2, "Social Justice", 1),
    (12, 4, "Technology", 1), (13, 2, "Children & Youth", 1), (14, 4, "Health", 1),
    (15, 4, "Mental Health", 1), (16, 4, "Disability Support", 1),
    (17, 2, "Homelessness", 1), (18, 3, "Literacy", 1), (19, 2, "Disaster Relief", 1),
    (20, 2, "Sports", 1), (21, 8, "Music", 1), (22, 2, "Refugees", 1),
]


def downgrade() -> None:
    conn = op.get_bind()
    has_data = conn.execute(sa.text("SELECT COUNT(*) FROM categories")).scalar()
    if not has_data:
        return

    cat_case = _case("category_id", CATEGORY_REMAP_DOWN, "category_id")
    kw_case = _case("keyword_id", KEYWORD_REMAP_DOWN, "NULL")

    # Repoint FKs back to representative legacy ids before rebuilding the rows.
    op.execute(f"UPDATE programs SET category_id = {cat_case}")
    _remap_junction("user_interests", "user_id", kw_case)
    _remap_junction("program_keywords", "program_id", kw_case)

    # Restore the legacy 8 categories (rename 1-8, drop 9-11).
    cat_names = " ".join(f"WHEN {cid} THEN '{name}'" for cid, name in LEGACY_CATEGORIES)
    op.execute(
        f"UPDATE categories SET category_name = CASE category_id {cat_names} "
        f"ELSE category_name END WHERE category_id BETWEEN 1 AND 8"
    )
    op.execute("DELETE FROM categories WHERE category_id > 8")

    # Restore the legacy 22 keywords.
    op.execute("DELETE FROM keywords")
    rows = ", ".join(
        f"({kid}, {cid}, '{name}', {is_int})"
        for kid, cid, name, is_int in LEGACY_KEYWORDS
    )
    op.execute(
        "INSERT INTO keywords (keyword_id, category_id, keyword_name, is_interest) "
        f"VALUES {rows}"
    )
