SHOW databases;

-- Podsumowanie z udzielanych kredytów:
-- w zależności od daty
-- Wynik zawierający informacje:
-- sumaryczna kwota pożyczek,
-- średnia kwota pożyczki,
-- całkowita liczba udzielonych pożyczek.

SELECT
YEAR(date) AS Year
, QUARTER(date) AS Quarter
, MONTH(date) AS Months
, count(loan_id) AS "Number of loans"
, AVG(amount) AS "Avg of amount"
, sum(amount) AS "Sum of amounts"
FROM loan
GROUP BY 1, 2, 3
WITH ROLLUP
ORDER BY 1, 2, 3;


-- Uszeregowanie kont według następujących kryteriów:
-- liczba udzielonych pożyczek (malejąco),
-- kwota udzielonych pożyczek (malejąco),
-- średnia kwota pożyczki.
-- Pod uwagę bierzemy tylko spłacone pożyczki - status = 'A' lub 'C'.

SELECT account_id
, count(loan_id) OVER (partition by account_id) AS "Number of loans"
, amount
, AVG(amount) OVER (partition by account_id) "Average amount of loan on this account"
FROM loan
WHERE
    status = 'A' OR status = 'C'
ORDER BY 2 DESC, 3 DESC, 4;


-- Spłacone pożyczki w podziale na płeć klienta.

SELECT
    count(l.loan_id)
, c.gender
FROM loan AS l
LEFT JOIN account AS a ON l.account_id = a.account_id
JOIN disp AS d ON d.account_id = a.account_id
JOIN client AS c ON d.client_id = c.client_id
WHERE (status IN ('A', 'C')) AND (d.type = "OWNER")
GROUP BY c.gender;

-- Sprawdzenie - poprawności zapytania
SELECT count(loan_id)
FROM loan WHERE (status IN ('A', 'C'));

-- Pytanie: kto posiada więcej spłaconych pożyczek – kobiety czy mężczyźni?

SELECT
    count(l.loan_id)
, c.gender
FROM loan AS l
LEFT JOIN account AS a ON l.account_id = a.account_id
JOIN disp AS d ON d.account_id = a.account_id
JOIN client AS c ON d.client_id = c.client_id
WHERE (status IN ('B', 'D')) AND (d.type = "OWNER")
GROUP BY c.gender;

-- Obliczenie % spłaconych pożyczek

SELECt ROUND(100* 307/ (307+41)) AS Kobiety
, ROUND(100* 299/ (299+35)) AS Mezczyzni

-- Odp: 307 Kobiet do 299 Mężczyzn, co stanowi wskaznik 88% dla kobiet i 90% dla męzczyzn

-- Jaki jest średni wiek kredytobiorcy w zależności od płci?
SELECT
    YEAR(Now()) - ROUND(avg(YEAR(c.birth_date)), 0) AS 'Sredni wiek w latach'
, c.gender
FROM loan AS l
LEFT JOIN account AS a ON l.account_id = a.account_id
JOIN disp AS d ON d.account_id = a.account_id
JOIN client AS c ON d.client_id = c.client_id
WHERE d.type = "OWNER"
GROUP BY c.gender;



-- Rejon, w którym jest najwięcej klientów,
SELECT
    count(distinct c.client_id) AS "Amount of clients"
, di.A2
FROM client AS c
JOIN disp AS d ON d.client_id = c.client_id
JOIN account AS a ON d.account_id = a.account_id
JOIN district AS di ON c.district_id = di.district_id
WHERE d.type = "OWNER"
GROUP BY di.A2 ORDER BY 1 DESC;

-- Rejon, w którym zostało spłaconych najwięcej pożyczek ilościowo,

SELECT
    count(l.loan_id) AS "Amount of paided loans"
, c.district_id
FROM loan AS l
LEFT JOIN account AS a ON l.account_id = a.account_id
JOIN disp AS d ON d.account_id = a.account_id
JOIN district AS c ON c.district_id = a.district_id
WHERE (status IN ('A', 'C')) AND (d.type = "OWNER")
GROUP BY c.district_id ORDER BY 1 DESC;


-- Rejon, w którym zostało spłaconych najwięcej pożyczek kwotowo,

SELECT
    sum(l.amount) AS "Sum of paided loans"
, c.district_id
FROM loan AS l
LEFT JOIN account AS a ON l.account_id = a.account_id
JOIN disp AS d ON d.account_id = a.account_id
JOIN district AS c ON a.district_id = c.district_id
WHERE (status IN ('A', 'C')) AND (d.type = "OWNER")
GROUP BY c.district_id ORDER BY 1 DESC;


-- Rozkład % pożyczek z podzialem na regiony

SELECT
distinct d2.district_id
, count(c.client_id) OVER (partition by d2.district_id) AS customer_amount
, sum(l.amount) OVER (partition by d2.district_id) AS loans_given_amount
, count(l.loan_id) OVER (partition by d2.district_id) AS loans_given_count
-- , sum(l.amount) OVER (partition by d2.district_id) AS amount_share
-- , sum(l.amount) OVER () AS suma
, (100* sum(l.amount) OVER (partition by d2.district_id)) / (sum(l.amount) OVER ())
AS amount_share
FROM loan AS l
JOIN account AS a ON l.account_id = a.account_id
JOIN disp AS d ON d.account_id = a.account_id
JOIN client AS c ON c.client_id = d.client_id
JOIN district AS d2 ON c.district_id = d2.district_id
WHERE (status IN ('A', 'C')) AND (d.type = "OWNER")
ORDER BY 4 DESC;


-- Wyszukiwanie klientów spełniających poniższe warunki:
-- saldo konta przekracza 1000,
-- mają więcej niż pięć pożyczek,
-- są urodzeni po 1990 r.
-- Przy czym zakładamy, że saldo konta to kwota pożyczki - wpłaty

SELECT distinct c.client_id,
--        c.birth_date AS cc,
count(l.loan_id) AS loan_count
, sum(l.amount - l.payments) AS saldo
FROM loan AS l
JOIN account AS a ON l.account_id = a.account_id
JOIN disp d on a.account_id = d.account_id
JOIN client c on d.client_id = c.client_id
WHERE c.birth_date > 1990
GROUP BY c.client_id
HAVING
    sum(l.amount - l.payments) > 1000
    AND COUNT(loan_id) > 5; -- Brak klientów dla ktorych COUNT(loan_id) > 1

-- Procedura odświeżająca tabelę z informacjami:
-- id klienta, id_karty, data wygaśnięcia – założenie:karta może być aktywna przez 3 lata od wydania,
-- adres klienta (kolumna A3).
DROP PROCEDURE IF EXISTS expiration;
DELIMITER $$
CREATE PROCEDURE expiration(IN p_date date)
BEGIN
Drop table if exists cards_at_expiration;
CREATE TABLE cards_at_expiration AS
SELECT  client_id
, card_id
, Date_of_expired
, Address
FROM (
SELECT cl.client_id
, c.card_id
, DATE_ADD(issued, INTERVAL 3 year) AS Date_of_expired
, A3 AS Address FROM card AS c
JOIN disp AS d ON c.disp_id = d.disp_id
JOIN client AS cl ON cl.client_id = d.client_id
JOIN district AS di ON di.district_id = cl.district_id) AS gg
WHERE Date_of_expired < p_date
;
END;
DELIMITER $$
Call expiration('1998-04-19');

SELECT * FROM cards_at_expiration;