SELECT * FROM actor_analytics;
-- Sprawdzenie za jaki % wpływów odpowiada 20% najbardziej wpływowych aktorów
DROP temporary table actors_podzial;
-- Przygotowania do odpowiedzi

CREATE temporary table actors_podzial AS
SELECT
actor_id,
actor_payload,
Case
    WHEN ROW_NR < 41 THEN '20%'
    ELSE '80%'
     END AS Partitio
FROM
    (SELECT
actor_id,
actor_payload,
ROW_NUMBER() OVER (ORDER BY actor_payload) AS ROW_NR
FROM actor_analytics
ORDER BY actor_payload) AS aa;


-- Właściwa odpowiedź
SELECT actor_id,
Partitio,
(SUM(actor_payload) OVER
    (PARTITION BY Partitio)) / 3675.5907 AS
    '% przychody danej Partycji aktorów w odniesieniu do całości'

FROM actors_podzial;


-- Obliczenie sumy wszystkich wpływów do następnego pytania
SELECT
    SUM(actor_payload)
FROM actors_podzial;

-- % wpływów pochodzący od każdego z aktorów z osobna
SELECT
actor_id,
(( 100 * actor_payload) / (
    SELECT sum(actor_payload)
    FROM actor_analytics
    )) AS Wplywy
-- count(actor_id) OVER ()
FROM actor_analytics
ORDER BY Wplywy DESC;





