/*
Tutaj zdefiniuj schemę `reporting`
*/

CREATE SCHEMA  reporting;
/*
Tutaj napisz definicję widoku reporting.flight, która:
- będzie usuwać dane o lotach anulowanych `cancelled = 0`
- będzie zawierać kolumnę `is_delayed`, zgodnie z wcześniejszą definicją tj. `is_delayed = 1 if dep_delay_new > 0 else 0` (zaimplementowana w SQL)

Wskazówka:
- SQL - analiza danych > Dzień 4 Proceduralny SQL > Wyrażenia warunkowe
- SQL - analiza danych > Przygotowanie do zjazdu 2 > Widoki
*/

/*
Tworzenie tabeli w schema
*/
CREATE TABLE reporting.flight as
SELECT *
FROM public.flight
WHERE cancelled = 0
;

ALTER TABLE reporting.flight
ADD COLUMN is_delayed INTEGER;
UPDATE reporting.flight
SET is_delayed = CASE 
WHEN dep_delay_new > 0 
THEN 1 
ELSE 0 END;
/*
Tworzenie widoku
*/
CREATE VIEW reporting.flight2 as
SELECT *
FROM reporting.flight
;
/*
Tutaj napisz definicję widoku reporting.top_reliability_roads, która będzie zawierała następujące kolumny:
- `origin_airport_id`,
- `origin_airport_name`,
- `dest_airport_id`,
- `dest_airport_name`,
- `year`,
- `cnt` - jako liczba wykonananych lotów na danej trasie,
- `reliability` - jako odsetek opóźnień na danej trasie,
- `nb` - numerowane od 1, 2, 3 według kolumny `reliability`. W przypadku takich samych wartości powino zwrócić 1, 2, 2, 3... 
Pamiętaj o tym, że w wyniku powinny pojawić się takie trasy, na których odbyło się ponad 10000 lotów.

Wskazówka:
- SQL - analiza danych > Dzień 2 Relacje oraz JOIN > JOIN
- SQL - analiza danych > Dzień 3 - Analiza danych > Grupowanie
- SQL - analiza danych > Dzień 1 Podstawy SQL > Aliasowanie
- SQL - analiza danych > Dzień 1 Podstawy SQL > Podzapytania
*/
/*
Tworzenie tabeli z groupby - postgresql nie pozwalał zastosować joinów razem z groupby
*/

CREATE TABLE reporting.top_reliability_roads AS
SELECT 
reporting.flight2.origin_airport_id,
reporting.flight2.dest_airport_id,
reporting.flight2.year,
COUNT(reporting.flight2.id) AS cnt,
SUM(reporting.flight2.is_delayed) AS delays
FROM reporting.flight2
GROUP BY reporting.flight2.year, reporting.flight2.origin_airport_id, reporting.flight2.dest_airport_id 
;
/*
Tworzenie tabeli z joinami - postgresql nie pozwalał zastosować joinów razem z groupby
*/


CREATE TABLE reporting.top_reliability_roads2 AS
SELECT 
reporting.top_reliability_roads.origin_airport_id,
al.display_airport_name AS origin_airport_name,
reporting.top_reliability_roads.dest_airport_id,
al2.display_airport_name AS dest_airport_name,
reporting.top_reliability_roads.cnt AS cnt,
year,
ROUND(100*CAST(reporting.top_reliability_roads.delays AS numeric) / CAST(reporting.top_reliability_roads.cnt AS numeric)) AS reliability
FROM reporting.top_reliability_roads
join public.airport_list AS al ON reporting.top_reliability_roads.origin_airport_id = al.origin_airport_id
join public.airport_list AS al2 ON reporting.top_reliability_roads.dest_airport_id = al2.origin_airport_id
WHERE cnt >= 10000;

/*
Tworzenie widoku z rankowaniem
*/
CREATE OR REPLACE VIEW reporting.top_reliability_roads3 AS
SELECT 
origin_airport_id,
origin_airport_name,
dest_airport_id,
dest_airport_name,
cnt,
year,
reliability,
DENSE_RANK() OVER ( ORDER BY reliability) AS nb
FROM reporting.top_reliability_roads2
;
/*
Tutaj napisz definicję widoku reporting.year_to_year_comparision, która będzie zawierał następujące kolumny:
- `year`
- `month`,
- `flights_amount`
- `reliability`
*/
CREATE VIEW reporting.year_to_year_comparision AS
SELECT 
year,
month, 
COUNT(id) AS flights_amount,
ROUND(100*CAST (SUM(is_delayed) AS numeric) / CAST (COUNT(id) AS numeric)) AS reliability
FROM reporting.flight
GROUP BY year, month
;
/*
Tutaj napisz definicję widoku reporting.day_to_day_comparision, który będzie zawierał następujące kolumny:
- `year`
- `day_of_week`
- `flights_amount`
*/
CREATE OR REPLACE VIEW reporting.day_to_day_comparision AS
SELECT 
year,
day_of_week, 
COUNT(id) AS flights_amount
FROM reporting.flight
GROUP BY year, day_of_week
;

/*
Tutaj napisz definicję widoku reporting.day_by_day_reliability, ktory będzie zawierał następujące kolumny:
- `date` jako złożenie kolumn `year`, `month`, `day`, powinna być typu `date`
- `reliability` jako odsetek opóźnień danego dnia

Wskazówki:
- formaty dat w postgresql: [klik](https://www.postgresql.org/docs/13/functions-formatting.html),
- jeśli chcesz dodać zera na początek liczby np. `1` > `01`, posłuż się metodą `LPAD`: [przykład](https://stackoverflow.com/questions/26379446/padding-zeros-to-the-left-in-postgresql),
- do konwertowania ciągu znaków na datę najwygodniej w Postgres użyć `to_date`: [przykład](https://www.postgresqltutorial.com/postgresql-date-functions/postgresql-to_date/)
- do złączenia kilku kolumn / wartości typu string, używa się operatora `||`, przykładowo: SELECT 'a' || 'b' as example

Uwaga: Nie dodawaj tutaj na końcu srednika - przy używaniu split, pojawi się pusta kwerenda, co będzie skutkowało późniejszym błędem przy próbie wykonania skryptu z poziomu notatnika.
*/
CREATE OR REPLACE VIEW reporting.day_by_day_reliability AS
SELECT
TO_DATE(year || '-' || month || '-' || day_of_month, 'YYYY-MM-DD') AS date,
ROUND(100*CAST (SUM(is_delayed) AS numeric) / CAST (COUNT(id) AS numeric)) AS reliability
FROM reporting.flight
GROUP BY date
