# goit-rdb-fp

Final project of the relational databases course: analysis of the `infectious_cases` dataset
(infectious disease statistics by country and year) in PostgreSQL.

## Contents

| Path                        | Description                                                              |
|---                          |---                                                                       |
| `final_project.ipynb`       | The solution: all steps with explanations and saved outputs              |
| `sql/final_project.sql`     | All SQL from the notebook as one script, in execution order              |
| `data/infectious_cases.csv` | Source dataset (10,521 rows). The notebook downloads it if it is missing |
| `requirements.txt`          | Python dependencies                                                      |

## How to run

PostgreSQL runs inside the notebook with [pgserver](https://pypi.org/project/pgserver/) (data in
`/tmp/final_project`), so no separate database installation is needed. Python 3.10 is used.

```bash
python3.10 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
jupyter lab final_project.ipynb   # then Run All
```

The notebook also works in Google Colab: the first cell installs the dependencies.

To run only the SQL in your own PostgreSQL, execute `sql/final_project.sql`. Load the CSV into
`pandemic.infectious_cases` after the `CREATE TABLE` step with the `\copy` command given in the
script header.

## What is done

1. **Load data.** Schema `pandemic` is created and set as default (`CREATE SCHEMA IF NOT EXISTS pandemic;
   SET search_path TO pandemic;`). The CSV is imported into `pandemic.infectious_cases`
   (10,521 rows, 245 entities, 1920-2023). All raw columns are `TEXT`, missing values are empty strings.
2. **Normalization to 3NF.** `Entity -> Code` is a partial dependency on the key `(Entity, Year)`, so the
   table is split into
   * `entities (entity_id, entity_name, entity_code)` - unique Entity + Code combinations (245 rows);
   * `disease_cases (entity_id, year, indicators...)` - indicators with `entity_id` instead of Entity and
     Code, primary key `(entity_id, year)` (10,521 rows), typed as `NUMERIC` with empty strings as `NULL`.

   A lossless check confirms that joining the tables back gives the original data.
3. **Analysis.** Average, minimum, maximum and sum of `number_rabies` per Entity + Code, sorted by the
   average in descending order, top 10 rows.
4. **Year difference column.** `MAKE_DATE(year, 1, 1)`, `CURRENT_DATE` and
   `EXTRACT(YEAR FROM AGE(CURRENT_DATE, MAKE_DATE(year, 1, 1)))`.
5. **Functions.**
   * `fn_years_since(year)` - difference in years between today and January 1st of the year;
   * `fn_avg_cases_per_period(cases_per_year, divisor)` - average cases per period, tested with the
     divisors 12 (month), 4 (quarter) and 2 (half-year) on records with numeric rabies values.

Both functions are used in queries on the normalized tables.
