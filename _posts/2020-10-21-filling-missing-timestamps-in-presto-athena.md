---
title: Filling missing timestamps using Amazon Athena
date: '2020-10-21 17:19:17'
layout: post
tags:
  - presto
  - athena
  - sql
  - aws
---

Working with moderate numbers of sparse time series is pretty straightforward using standard tools like pandas, but increasingly I have to work with large numbers of sparse time series in Amazon Athena / PrestoDB and so those handy pandas functions aren't always available.

This week, I had to figure out how to insert missing timestamp values in a large number of sparse time series prior to computing an aggregate. Typically, this is something you'd use pandas' [resample](https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.DataFrame.resample.html) functionality for but, at the scale I had to work at, pulling data back into memory just wasn't an option. Happily, it turns out that this is pretty easy to do directly in Athena.

First a simple example: say you have a table that stores products and their corresponding order dates and you want to count the number of distinct products sold per day. That is, the input data might look something like this:

```
|----------------------|
| order_date | product |
|----------------------|
| 2020-01-05 | apple   |
| 2020-01-05 | banana  |
| 2020-01-10 | carrot  |
| 2020-01-12 | daikon  |
|----------------------|
```

And you want the output to look like this:

```
|-------------------------|
| order_date | n_products |
|-------------------------|
| 2020-01-05 | 2          |
| 2020-01-06 | 0          |
| 2020-01-07 | 0          |
| 2020-01-08 | 0          |
| 2020-01-09 | 0          |
| 2020-01-10 | 1          |
| 2020-01-11 | 0          |
| 2020-01-12 | 1          |
|-------------------------|
```

If we call the input data table `orders` , then we can produce the output above as follows:

```sql
SELECT dates.order_date,
       COUNT(DISTINCT orders.product) AS n_products
FROM (
  SELECT date_add('day', s.n, min_date) AS order_date
  FROM (
    SELECT MIN(order_date) AS min_date,
           MAX(order_date) AS max_date
    FROM orders
  )
  CROSS JOIN UNNEST(
    sequence(0, date_diff('day', min_date, max_date))
  ) AS s (n)
) AS dates
LEFT JOIN orders
USING (order_date)
GROUP BY 1
ORDER BY 1
```

The key idea is to use a subquery to figure out the start and end dates of the data and then use a `CROSS JOIN` over a sequence whose length is equal to the number of days between the earliest and most recent order dates (Presto allows referencing fields from the left hand side of the cross join operation, so we can use `min_date` and `max_date` inside the `UNNEST` statement). This works for other time resolutions too - you just need to change the time unit used in the `date_add` and `date_diff` functions.

Next, a more complex (and realistic) example: what if you also store customer IDs inside your table and you want to resample time series per customer rather than globally? That is, you have a table that looks a bit like this:

```
|------------------------------------|
| customer_id | order_date | product |
|------------------------------------|
| 0           | 2020-01-05 | apple   |
| 0           | 2020-01-05 | banana  |
| 0           | 2020-01-10 | carrot  |
| 0           | 2020-01-12 | daikon  |
| 1           | 2020-01-10 | apple   |
| 1           | 2020-01-15 | banana  |
|------------------------------------|
```

And you want an output that looks like this:

```
|---------------------------------------|
| customer_id | order_date | n_products |
|---------------------------------------|
| 0           | 2020-01-05 | 2          |
| 0           | 2020-01-06 | 0          |
| 0           | 2020-01-07 | 0          |
| 0           | 2020-01-08 | 0          |
| 0           | 2020-01-09 | 0          |
| 0           | 2020-01-10 | 1          |
| 0           | 2020-01-11 | 0          |
| 0           | 2020-01-12 | 1          |
| 1           | 2020-01-10 | 1          |
| 1           | 2020-01-11 | 0          |
| 1           | 2020-01-12 | 0          |
| 1           | 2020-01-13 | 0          |
| 1           | 2020-01-14 | 0          |
| 1           | 2020-01-15 | 1          |
|---------------------------------------|
```

Again, calling the input data table `orders` , we can produce the output as follows:

```sql
SELECT dates.customer_id,
       dates.order_date,
       COUNT(DISTINCT orders.product) AS n_products
FROM (
  SELECT customer_id,
         date_add('day', s.n, min_date) AS order_date
  FROM (
    SELECT customer_id,
           MIN(order_date) AS min_date,
           MAX(order_date) AS max_date
    FROM orders
    GROUP BY 1
  )
  CROSS JOIN UNNEST(
    sequence(0, date_diff('day', min_date, max_date))
  ) AS s (n)
) AS dates
LEFT JOIN orders
USING (customer_id, order_date)
GROUP BY 1, 2
ORDER BY 1, 2
```

This is the same trick as before, but the subquery is modified so that it computes the time boundaries for each customer ID. After that, it's just a matter of joining on the additional `customer_id` key.
