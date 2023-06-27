
-- Procedura generate_payment_report, która będzie przyjmowała datę,
-- na który dzień ma zostać wygenerowany raport, a następnie zapisze wyniki do tabeli employees.payment_report.
-- Załóż dodatkowo, że raport ma być dostępny na koniec danego miesiąca.



DROP PROCEDURE IF EXISTS generate_payment_report;
DELIMITER $$
CREATE PROCEDURE generate_payment_report(IN p_date date)

BEGIN
-- Tabela wybierająca rekordy z aktualnymi datami wciąż zatrudnionych
DROP temporary table IF EXISTS emp_list;
CREATE temporary table emp_list AS

SELECT emp_no,  MIN(to_date) AS date
FROM (SELECT * FROM salaries
WHERE to_date > p_date) AS salaries2
GROUP BY emp_no ;

-- Tabela wybierająca wynagrodzenia wciąż zatrudnionych
DROP temporary table IF EXISTS olders_rows;
CREATE temporary table olders_rows AS

SELECT salaries.emp_no AS emp_no, salaries.salary AS salary
FROM salaries
INNER JOIN emp_list ON salaries.emp_no = emp_list.emp_no
WHERE salaries.to_date = emp_list.date;

-- Tabela łącząca dwie powyższe
DROP temporary table IF EXISTS temp_salaries;
CREATE temporary table temp_salaries AS
SELECT e.emp_no,
       e.date,
       o.salary
FROM emp_list AS e
INNER JOIN olders_rows AS o ON e.emp_no = o.emp_no;

-- Tabela obliczająca średnie wynagrodzeń

DROP temporary table IF EXISTS srednie;
CREATE temporary table srednie AS
    SELECT
     d.dept_name
     , AVG(s.salary) AS 'AVG salary'
FROM employees AS e
INNER JOIN
olders_rows  AS s
ON e.emp_no = s.emp_no
INNER JOIN
dept_emp AS de
ON de.emp_no = e.emp_no
INNER JOIN departments AS d ON d.dept_no = de.dept_no
GROUP BY d.dept_name;


-- Ostateczny wynik
SELECT
    e.gender
    , d.dept_name
    , AVG(s.salary) AS avg_salary
    , count(dept_emp.emp_no) AS amount
    , 100* AVG(s.salary) /
      (SELECT `AVG salary` FROM srednie WHERE dept_name = d.dept_name) AS diff
    , LAST_DAY(p_date) AS report_date
     , NOW() AS report_generation_date
FROM emp_list
LEFT JOIN
temp_salaries AS s ON emp_list.emp_no = s.emp_no
INNER JOIN employees AS e ON s.emp_no = e.emp_no
INNER JOIN dept_emp ON dept_emp.emp_no = s.emp_no
INNER JOIN departments AS d ON d.dept_no = dept_emp.dept_no
GROUP BY e.gender, d.dept_name;
END;
DELIMITER $$;


-- Sprawdzenie działania na przykładowej dacie
call generate_payment_report('2000-10-11'); 
