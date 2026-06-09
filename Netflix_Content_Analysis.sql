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
    listed_in    TEXT,        -- comma-separated genres
    description  TEXT
);

CREATE TABLE netflix AS
SELECT
    show_id,
    type,
    title,
    NULLIF(TRIM(director), '') AS director,
    NULLIF(TRIM(cast_members), '') AS cast_members,
    NULLIF(TRIM(country), '') AS country,
    TO_DATE(TRIM(date_added), 'Month DD, YYYY') AS date_added,
    release_year,
    NULLIF(TRIM(rating), '') AS rating,
    duration,
    listed_in,
    description
FROM netflix_raw
WHERE title IS NOT NULL;

-- Row count and type breakdown
SELECT type, COUNT(*) AS total,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM netflix
GROUP BY type;

-- Null/missing value audit across all key columns
SELECT
  COUNT(*) FILTER (WHERE director IS NULL)     AS missing_director,
  COUNT(*) FILTER (WHERE country IS NULL)      AS missing_country,
  COUNT(*) FILTER (WHERE date_added IS NULL)   AS missing_date_added,
  COUNT(*) FILTER (WHERE rating IS NULL)       AS missing_rating,
  COUNT(*) FILTER (WHERE cast_members IS NULL) AS missing_cast
FROM netflix;

-- Earliest and latest content added to Netflix
SELECT MIN(date_added) AS first_added,
       MAX(date_added) AS last_added,
       MAX(date_added) - MIN(date_added) AS span_days
FROM netflix;

-- Content where release year ≠ year added (licensed old content)
SELECT title, type, release_year,
       EXTRACT(YEAR FROM date_added) AS year_added,
       EXTRACT(YEAR FROM date_added) - release_year AS years_gap
FROM netflix
WHERE date_added IS NOT NULL
ORDER BY years_gap DESC
LIMIT 20;

-- Duplicate title check
SELECT title, type, COUNT(*) AS cnt
FROM netflix
GROUP BY title, type
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- Titles added per year (TIME SERIES)
SELECT EXTRACT(YEAR FROM date_added) AS yr,
       COUNT(*) AS titles_added
FROM netflix
WHERE date_added IS NOT NULL
GROUP BY yr
ORDER BY yr;

-- Monthly seasonality — which month does Netflix add most content?
SELECT TO_CHAR(date_added, 'Mon') AS month,
       EXTRACT(MONTH FROM date_added) AS month_num,
       COUNT(*) AS titles_added
FROM netflix
WHERE date_added IS NOT NULL
GROUP BY month, month_num
ORDER BY month_num;

-- CTE — Year-over-year growth rate in content additions
WITH yearly AS (
    SELECT EXTRACT(YEAR FROM date_added)::INT AS yr,
           COUNT(*) AS titles
    FROM netflix
    WHERE date_added IS NOT NULL
    GROUP BY yr
),
growth AS (
    SELECT yr, titles,
           LAG(titles) OVER (ORDER BY yr) AS prev_year,
           ROUND((titles - LAG(titles) OVER (ORDER BY yr)) * 100.0 /
                 NULLIF(LAG(titles) OVER (ORDER BY yr), 0), 2) AS yoy_pct
    FROM yearly
)
SELECT * FROM growth ORDER BY yr;

-- Movies vs TV Shows added per year (pivoted)
SELECT EXTRACT(YEAR FROM date_added)::INT AS yr,
       COUNT(*) FILTER (WHERE type = 'Movie')   AS movies,
       COUNT(*) FILTER (WHERE type = 'TV Show') AS tv_shows
FROM netflix
WHERE date_added IS NOT NULL
GROUP BY yr
ORDER BY yr;

-- Running cumulative total of content on platform
SELECT
    EXTRACT(YEAR FROM date_added)::INT AS yr,
    COUNT(*) AS added_this_year,
    SUM(COUNT(*)) OVER (ORDER BY EXTRACT(YEAR FROM date_added)::INT) AS cumulative_total
FROM netflix
WHERE date_added IS NOT NULL
GROUP BY yr
ORDER BY yr;

-- Explode listed_in into one genre per row
CREATE VIEW netflix_genres AS
SELECT show_id, type, country, date_added, release_year, rating,
       TRIM(genre) AS genre
FROM netflix,
     UNNEST(STRING_TO_ARRAY(listed_in, ',')) AS genre;

-- Top 15 most common genres overall
SELECT genre, COUNT(*) AS total
FROM netflix_genres
GROUP BY genre
ORDER BY total DESC
LIMIT 15;

-- Genre popularity by content type (Movie vs TV)
SELECT genre, type, COUNT(*) AS cnt
FROM netflix_genres
GROUP BY genre, type
ORDER BY genre, cnt DESC;

-- Genre trends over time — top 5 genres per year
WITH genre_year AS (
    SELECT EXTRACT(YEAR FROM date_added)::INT AS yr,
           genre, COUNT(*) AS cnt
    FROM netflix_genres
    WHERE date_added IS NOT NULL
    GROUP BY yr, genre
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY yr ORDER BY cnt DESC) AS rnk
    FROM genre_year
)
SELECT yr, genre, cnt
FROM ranked
WHERE rnk <= 5
ORDER BY yr, rnk;

-- CROSS JOIN — genre co-occurrence (which genres appear together most?)
WITH exploded AS (
    SELECT show_id,
           TRIM(g) AS genre
    FROM netflix,
         UNNEST(STRING_TO_ARRAY(listed_in, ',')) g
)
SELECT a.genre AS genre_a, b.genre AS genre_b, COUNT(*) AS co_occurrences
FROM exploded a
JOIN exploded b ON a.show_id = b.show_id AND a.genre < b.genre
GROUP BY a.genre, b.genre
ORDER BY co_occurrences DESC
LIMIT 20;

-- Top content-producing countries
SELECT TRIM(SPLIT_PART(country, ',', 1)) AS primary_country,
       COUNT(*) AS titles
FROM netflix
WHERE country IS NOT NULL
GROUP BY primary_country
ORDER BY titles DESC
LIMIT 15;

-- Dominant genre per country (CTE + RANK)
WITH country_genre AS (
    SELECT TRIM(SPLIT_PART(n.country, ',', 1)) AS country,
           TRIM(g.genre) AS genre,
           COUNT(*) AS cnt
    FROM netflix n,
         UNNEST(STRING_TO_ARRAY(n.listed_in, ',')) AS g(genre)
    WHERE n.country IS NOT NULL
    GROUP BY country, genre
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY country ORDER BY cnt DESC) AS rnk
    FROM country_genre
)
SELECT country, genre, cnt
FROM ranked
WHERE rnk = 1 AND cnt > 5
ORDER BY cnt DESC;

-- Countries that produce exclusively Movies or exclusively TV Shows
SELECT TRIM(SPLIT_PART(country, ',', 1)) AS country,
       COUNT(DISTINCT type) AS type_count,
       STRING_AGG(DISTINCT type, ', ') AS types
FROM netflix
WHERE country IS NOT NULL
GROUP BY country
HAVING COUNT(DISTINCT type) = 1
ORDER BY country;

-- International vs US content ratio by year
SELECT EXTRACT(YEAR FROM date_added)::INT AS yr,
       COUNT(*) FILTER (WHERE country ILIKE '%United States%') AS us_titles,
       COUNT(*) FILTER (WHERE country NOT ILIKE '%United States%'
                        AND country IS NOT NULL) AS intl_titles
FROM netflix
WHERE date_added IS NOT NULL
GROUP BY yr
ORDER BY yr;

-- Rating distribution
SELECT rating, COUNT(*) AS total,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM netflix
WHERE rating IS NOT NULL
GROUP BY rating
ORDER BY total DESC;

-- Average movie duration by genre
SELECT TRIM(g) AS genre,
       ROUND(AVG(REPLACE(duration, ' min', '')::INT), 1) AS avg_minutes,
       MIN(REPLACE(duration, ' min', '')::INT) AS min_min,
       MAX(REPLACE(duration, ' min', '')::INT) AS max_min
FROM netflix,
     UNNEST(STRING_TO_ARRAY(listed_in, ',')) AS g
WHERE type = 'Movie' AND duration ILIKE '%min%'
GROUP BY genre
ORDER BY avg_minutes DESC;

-- TV Show season distribution
SELECT duration AS seasons,
       COUNT(*) AS shows
FROM netflix
WHERE type = 'TV Show'
GROUP BY duration
ORDER BY shows DESC;

-- Most prolific directors on Netflix
SELECT director, COUNT(*) AS titles,
       STRING_AGG(DISTINCT type, ', ') AS content_types
FROM netflix
WHERE director IS NOT NULL
GROUP BY director
ORDER BY titles DESC
LIMIT 15;

-- CTE — Directors who made both Movies AND TV Shows
WITH director_types AS (
    SELECT director,
           COUNT(DISTINCT type) AS type_count,
           COUNT(*) AS total_titles
    FROM netflix
    WHERE director IS NOT NULL
    GROUP BY director
)
SELECT director, total_titles
FROM director_types
WHERE type_count = 2
ORDER BY total_titles DESC
LIMIT 10;

-- Full content strategy summary dashboard per year
WITH yearly_stats AS (
    SELECT
        EXTRACT(YEAR FROM date_added)::INT AS yr,
        COUNT(*) AS total_titles,
        COUNT(*) FILTER (WHERE type = 'Movie') AS movies,
        COUNT(*) FILTER (WHERE type = 'TV Show') AS tv_shows,
        COUNT(DISTINCT TRIM(SPLIT_PART(country,',',1))) AS unique_countries,
        ROUND(AVG(CASE WHEN type='Movie'
              THEN REPLACE(duration,' min','')::INT END), 1) AS avg_movie_mins
    FROM netflix
    WHERE date_added IS NOT NULL
    GROUP BY yr
)
SELECT *,
       SUM(total_titles) OVER (ORDER BY yr) AS cumulative_library,
       ROUND(movies * 100.0 / NULLIF(total_titles,0), 1) AS movie_share_pct
FROM yearly_stats
ORDER BY yr;