<div align="center">

<img src="https://img.shields.io/badge/PostgreSQL-15+-336791?style=for-the-badge&logo=postgresql&logoColor=white"/>
<img src="https://img.shields.io/badge/Dataset-Kaggle-20BEFF?style=for-the-badge&logo=kaggle&logoColor=white"/>
<img src="https://img.shields.io/badge/Titles-8%2C800%2B-E50914?style=for-the-badge&logo=netflix&logoColor=white"/>
<img src="https://img.shields.io/badge/Queries-25-141414?style=for-the-badge"/>
<img src="https://img.shields.io/badge/Level-Intermediate-orange?style=for-the-badge"/>

# 🎬 Netflix Content Strategy & Genre Analysis

### An intermediate PostgreSQL project analysing Netflix's full content catalogue

*Discover content addition trends, genre dominance by region, rating distributions, and the evolving balance between originals and licensed content.*

**Prepared by · Mounika**

</div>

---

## 📌 Problem Statement

> **How has Netflix's content strategy shifted over time, and which genres dominate specific regional markets?**

This project uses real-world Netflix catalogue data to answer that question through **25 structured SQL queries** spanning six analytical themes — from raw data exploration all the way to a full year-level content strategy dashboard.

---

## 📁 Dataset

| Field | Detail |
|-------|--------|
| **Source** | [Kaggle — Netflix Movies and TV Shows](https://www.kaggle.com/datasets/shivamb/netflix-shows) |
| **Author** | Shivam Bansal (`shivamb`) |
| **File** | `netflix_titles.csv` |
| **Size** | 8,800+ rows · ~3 MB |
| **Licence** | CC0: Public Domain |

### Download Steps
1. Sign in (or register free) at [kaggle.com](https://www.kaggle.com)
2. Go to → https://www.kaggle.com/datasets/shivamb/netflix-shows
3. Click **Download** → extract `netflix_titles.csv`

### Columns

| Column | Type | Description |
|--------|------|-------------|
| `show_id` | TEXT | Unique ID per title |
| `type` | TEXT | `Movie` or `TV Show` |
| `title` | TEXT | Title name |
| `director` | TEXT | Director (nullable) |
| `cast_members` | TEXT | Comma-separated cast |
| `country` | TEXT | Production country/ies |
| `date_added` | TEXT → DATE | Date added to Netflix |
| `release_year` | INT | Original release year |
| `rating` | TEXT | Content rating (TV-MA, PG-13 …) |
| `duration` | TEXT | Runtime in minutes or seasons |
| `listed_in` | TEXT | Comma-separated genres |
| `description` | TEXT | Plot summary |

---

## 🚀 Getting Started

### Prerequisites
- PostgreSQL 13+ (15 recommended)
- pgAdmin 4, DBeaver, or any Postgres client
- The `netflix_titles.csv` file downloaded from Kaggle

### Setup — Run in Order

**Step 1 · Create the raw table**
```sql
CREATE TABLE netflix_raw (
    show_id      TEXT,
    type         TEXT,
    title        TEXT,
    director     TEXT,
    cast_members TEXT,
    country      TEXT,
    date_added   TEXT,
    release_year INT,
    rating       TEXT,
    duration     TEXT,
    listed_in    TEXT,
    description  TEXT
);
```

**Step 2 · Load the CSV**
```sql
COPY netflix_raw
FROM '/absolute/path/to/netflix_titles.csv'
CSV HEADER QUOTE '"' ESCAPE '\';
```

**Step 3 · Create clean working table (parse dates + handle NULLs)**
```sql
CREATE TABLE netflix AS
SELECT
    show_id,
    type,
    title,
    NULLIF(TRIM(director), '')      AS director,
    NULLIF(TRIM(cast_members), '')  AS cast_members,
    NULLIF(TRIM(country), '')       AS country,
    TO_DATE(TRIM(date_added),
            'Month DD, YYYY')       AS date_added,
    release_year,
    NULLIF(TRIM(rating), '')        AS rating,
    duration,
    listed_in,
    description
FROM netflix_raw
WHERE title IS NOT NULL;
```

**Step 4 · Create the genre view (UNNEST magic)**
```sql
CREATE VIEW netflix_genres AS
SELECT
    show_id, type, country,
    date_added, release_year, rating,
    TRIM(genre) AS genre
FROM netflix,
     UNNEST(STRING_TO_ARRAY(listed_in, ',')) AS genre;
```

> ✅ You're ready. Run the queries in `queries/` in any order.

---

## 📂 Repository Structure

```
netflix-sql-analysis/
│
├── README.md                          ← You are here
├── setup/
│   └── 01_setup.sql                   ← Table creation, data load, view
│
├── queries/
│   ├── block1_exploration.sql         ← Q1–Q5   · Data quality
│   ├── block2_trends.sql              ← Q6–Q10  · Time series
│   ├── block3_genres.sql              ← Q11–Q15 · Genre analysis
│   ├── block4_regional.sql            ← Q16–Q19 · Country breakdown
│   ├── block5_ratings.sql             ← Q20–Q22 · Ratings & duration
│   └── block6_advanced.sql            ← Q23–Q25 · Directors & dashboard
│
└── docs/
    └── Netflix_SQL_Project_Documentation_Mounika.docx
```

---

## 🗂️ Query Index

### Block 1 — Data Exploration & Quality · Q1–Q5

| # | Query | Technique |
|---|-------|-----------|
| Q1 | Row count and type breakdown | `COUNT` · Window `%` |
| Q2 | NULL / missing value audit | `FILTER` clause |
| Q3 | Earliest and latest content added | `MIN` / `MAX` |
| Q4 | Release year vs year-added gap (licensed content) | `EXTRACT` · Date arithmetic |
| Q5 | Duplicate title detection | `GROUP BY` · `HAVING` |

### Block 2 — Content Addition Trends · Q6–Q10

| # | Query | Technique |
|---|-------|-----------|
| Q6  | Titles added per year | Time series |
| Q7  | Monthly seasonality of additions | `TO_CHAR` · `EXTRACT` |
| Q8  | Year-over-year growth rate | **CTE** + `LAG()` |
| Q9  | Movies vs TV Shows per year (pivot) | `FILTER` pivot |
| Q10 | Running cumulative library size | `SUM() OVER` |

### Block 3 — Genre Analysis · Q11–Q15

| # | Query | Technique |
|---|-------|-----------|
| Q11 | Top 15 genres overall | `UNNEST` · `STRING_TO_ARRAY` |
| Q12 | Genre popularity by content type | Multi-dim `GROUP BY` |
| Q13 | Top 5 genres per year | **CTE** + `RANK()` |
| Q14 | Genre co-occurrence matrix | **CROSS JOIN** · Self JOIN |
| Q15 | Top content-producing countries | `SPLIT_PART` |

### Block 4 — Regional Analysis · Q16–Q19

| # | Query | Technique |
|---|-------|-----------|
| Q16 | Dominant genre per country | **CTE** + `RANK() OVER (PARTITION BY)` |
| Q17 | Countries with single content type | `HAVING COUNT(DISTINCT)` |
| Q18 | International vs US content ratio by year | `ILIKE` · `FILTER` |
| Q19 | Rating distribution | Window `%` |

### Block 5 — Ratings & Duration · Q20–Q22

| # | Query | Technique |
|---|-------|-----------|
| Q20 | Average movie duration by genre | `UNNEST` · `CAST` |
| Q21 | TV Show season distribution | Aggregation |
| Q22 | Most prolific directors | `STRING_AGG` |

### Block 6 — Advanced Analysis · Q23–Q25

| # | Query | Technique |
|---|-------|-----------|
| Q23 | Directors who made both Movies AND TV Shows | **CTE** + `COUNT(DISTINCT)` |
| Q24 | Cast member frequency analysis | `UNNEST` · `STRING_TO_ARRAY` |
| Q25 | Full content strategy dashboard | **CTE** + multi-window |

---

## 🛠️ SQL Techniques Covered

```
✔ STRING_TO_ARRAY     Split comma-separated genre strings into arrays
✔ UNNEST              Explode arrays into rows — one genre per row per title
✔ CTE (WITH clause)   Multi-step logic for growth rates, rankings, dashboards
✔ Window Functions    LAG(), SUM() OVER, RANK() OVER (PARTITION BY ...)
✔ CROSS JOIN          Genre co-occurrence — pair every genre against every other
✔ Date Parsing        TO_DATE(), EXTRACT(), TO_CHAR() for time series analysis
✔ FILTER clause       Pivot counts by type/country inside a single GROUP BY
✔ SPLIT_PART          Extract primary country from comma-separated field
✔ STRING_AGG          Concatenate distinct values per group
✔ NULLIF / TRIM       Convert empty strings to proper NULLs on ingestion
```

---

## 💡 Sample Query

**Q8 — Year-over-year growth rate (CTE + LAG)**

```sql
WITH yearly AS (
    SELECT EXTRACT(YEAR FROM date_added)::INT AS yr,
           COUNT(*)                           AS titles
    FROM   netflix
    WHERE  date_added IS NOT NULL
    GROUP  BY yr
),
growth AS (
    SELECT yr, titles,
           LAG(titles) OVER (ORDER BY yr)                          AS prev_year,
           ROUND(
               (titles - LAG(titles) OVER (ORDER BY yr)) * 100.0 /
               NULLIF(LAG(titles) OVER (ORDER BY yr), 0), 2)       AS yoy_pct
    FROM yearly
)
SELECT * FROM growth ORDER BY yr;
```

**Q25 — Full strategy dashboard (multi-window)**

```sql
WITH yearly_stats AS (
    SELECT
        EXTRACT(YEAR FROM date_added)::INT                        AS yr,
        COUNT(*)                                                  AS total_titles,
        COUNT(*) FILTER (WHERE type = 'Movie')                   AS movies,
        COUNT(*) FILTER (WHERE type = 'TV Show')                 AS tv_shows,
        COUNT(DISTINCT TRIM(SPLIT_PART(country,',',1)))          AS unique_countries,
        ROUND(AVG(
            CASE WHEN type = 'Movie'
                 THEN REPLACE(duration,' min','')::INT END), 1) AS avg_movie_mins
    FROM   netflix
    WHERE  date_added IS NOT NULL
    GROUP  BY yr
)
SELECT *,
       SUM(total_titles) OVER (ORDER BY yr)   AS cumulative_library,
       ROUND(movies * 100.0 /
             NULLIF(total_titles, 0), 1)       AS movie_share_pct
FROM   yearly_stats
ORDER  BY yr;
```

---

## 📊 Key Insights (Spoilers)

- 📈 **Peak growth** occurred between **2016–2019** driven by Netflix's originals push
- 🎬 **Movies outnumber TV Shows ~2:1** across the entire catalogue
- 🌍 **"International Movies" + "Dramas"** are the two dominant genre tags globally
- 🇺🇸 US content skews Drama/Documentary · 🇮🇳 India heavily favours Action + International
- 🔞 **TV-MA** is the #1 content rating — Netflix's audience is primarily adult
- 📅 Content additions **spike in Q4** (Oct–Dec) — subscriber acquisition season
- 🎭 Most TV shows run **1–2 seasons** — limited series is the dominant format
- ⏳ Much licensed content was produced **5–15 years before** its Netflix addition

---

## 🔭 Extensions & Next Steps

- **Join with OWID data** — correlate content volume with CO₂ emissions by country
- **TMDB/IMDB enrichment** — add external ratings to measure quality vs volume
- **Stored procedure** — accept a genre input and return top 10 recent titles
- **Recursive CTE** — model a content recommendation path via shared genres
- **Visualisation** — pipe Q25 results into Python (matplotlib) or Tableau

---

## 📄 Documentation

Full project documentation (Word format) is in `/docs/`:

📘 `Netflix_SQL_Project_Documentation_Mounika.docx`

Includes dataset reference, column guide, setup steps, all 25 queries with explanation, expected insights, and learning outcomes.

---

## 👤 Author

**Mounika**
Netflix Content Strategy & Genre Analysis — PostgreSQL Intermediate Project

---

<div align="center">

*Built with PostgreSQL · Dataset from Kaggle · Prepared by Mounika*

</div>
