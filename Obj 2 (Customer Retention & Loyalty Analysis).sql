USE E_COMMERCE_SALES;

SELECT * FROM Customer;
SELECT * FROM Location;
SELECT * FROM Order_item;
SELECT * FROM Orders;
SELECT * FROM Product;
SELECT * FROM Review;


# OBJECTIVE 2 :- Analyze Customer Retention & Repeat Purchase Behavior
## TASK 1 :- Which product categories and brands have the highest repeat purchase rates among customers?

SELECT
    p.category_name,
    p.brand,

    COUNT(DISTINCT CASE
        WHEN o.customer_id IN
        (
            SELECT customer_id
            FROM Orders
            WHERE order_status='delivered'
            GROUP BY customer_id
            HAVING COUNT(order_id)>1
        )
        THEN o.customer_id
    END) AS repeat_customers,

    COUNT(DISTINCT o.customer_id) AS total_customers,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN o.customer_id IN
            (
                SELECT customer_id
                FROM Orders
                WHERE order_status='delivered'
                GROUP BY customer_id
                HAVING COUNT(order_id)>1
            )
            THEN o.customer_id
        END) * 100.0
        /
        COUNT(DISTINCT o.customer_id),
        2
    ) AS repeat_purchase_rate

FROM Orders o
JOIN Order_item i
    ON o.order_id=i.order_id
JOIN Product p
    ON i.product_id=p.product_id

WHERE o.order_status='delivered'

GROUP BY
    p.category_name,
    p.brand

ORDER BY repeat_customers DESC,
         repeat_purchase_rate DESC;

-- ORDER BY
--     repeat_purchase_rate DESC,
--     repeat_customers DESC;
---------------------------------------------------------------------------------------------------------------

## Task 2 - How do repeat purchase rates vary by customer segment (New vs. Loyal), gender, and age group 


SELECT c.customer_segment, c.gender, c.age_group,
			COUNT(CASE
            WHEN o.customer_id IN
            (SELECT customer_id FROM Orders
                WHERE order_status = 'delivered'
                GROUP BY customer_id
                HAVING COUNT(order_id) > 1)
            THEN 1
        END) AS repeat_customers,
		COUNT(*) AS total_customers,
	ROUND(
        COUNT(CASE
                WHEN o.customer_id IN
                (SELECT customer_id
                    FROM Orders
                    WHERE order_status = 'delivered'
                    GROUP BY customer_id
                    HAVING COUNT(order_id) > 1)
                THEN 1
            END) * 100.0 / COUNT(*),2) AS repeat_purchase_rate

FROM Customer c
JOIN Orders o
    ON c.customer_id = o.customer_id

WHERE o.order_status = 'delivered'
GROUP BY c.customer_segment,
		 c.gender,
		 c.age_group
ORDER BY
    repeat_purchase_rate DESC;
    
    
--------------------------------------------------------------------------------------------------------------------------

## Task 3 - How do discount rates, shipping costs, and unit prices influence the likelihood of repeat purchases within 30/60/90 days?


WITH Customer_Orders AS
(
    SELECT
        o.customer_id,
        o.order_id,
        o.order_purchase_timestamp,
        LEAD(o.order_id) OVER
        (
            PARTITION BY o.customer_id
            ORDER BY o.order_purchase_timestamp
        ) AS next_order_id,

        LEAD(o.order_purchase_timestamp) OVER
        (
            PARTITION BY o.customer_id
            ORDER BY o.order_purchase_timestamp
        ) AS next_order_date

    FROM Orders o
    WHERE o.order_status = 'Delivered'
)

SELECT
    CASE
        WHEN DATEDIFF(c.next_order_date, c.order_purchase_timestamp) <= 30
            THEN 'Within 30 Days'
        WHEN DATEDIFF(c.next_order_date, c.order_purchase_timestamp) <= 60
            THEN 'Within 60 Days'
        WHEN DATEDIFF(c.next_order_date, c.order_purchase_timestamp) <= 90
            THEN 'Within 90 Days'
        ELSE 'After 90 Days'
    END AS repeat_period,

    ROUND(AVG(i.discount),2) AS avg_discount,
    ROUND(AVG(i.shipping_cost),2) AS avg_shipping_cost,
    ROUND(AVG(i.unit_price),2) AS avg_unit_price,

    COUNT(DISTINCT c.customer_id) AS repeat_customers

FROM Customer_Orders c

JOIN Order_item i
    ON c.next_order_id = i.order_id

WHERE c.next_order_id IS NOT NULL

GROUP BY repeat_period

ORDER BY
CASE repeat_period
    WHEN 'Within 30 Days' THEN 1
    WHEN 'Within 60 Days' THEN 2
    WHEN 'Within 90 Days' THEN 3
    ELSE 4
END;



## Task 4 :- How can a SQL Trigger automatically track customer retention based on delivery performance and repeat purchases?


CREATE TABLE Customer_Retention (
    customer_id VARCHAR(50),
    order_id VARCHAR(50),
    delivery_status VARCHAR(20),
    repeat_purchase VARCHAR(10)
);


show triggers;


DELIMITER //

CREATE TRIGGER trg_customer_retention
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN

    DECLARE total_orders INT DEFAULT 0;
    DECLARE delivery_status VARCHAR(20);

    IF NEW.order_status = 'delivered'
       AND OLD.order_status <> 'delivered'
    THEN

        SELECT COUNT(*)
        INTO total_orders
        FROM Orders
        WHERE customer_id = NEW.customer_id
          AND order_status = 'delivered';

        IF NEW.order_delivered_customer_date <= NEW.order_estimated_delivery_date THEN
            SET delivery_status = 'On-Time';
        ELSE
            SET delivery_status = 'Delayed';
        END IF;

        INSERT INTO Customer_Retention
        (
            customer_id,
            order_id,
            delivery_status,
            repeat_purchase
        )
        VALUES
        (
            NEW.customer_id,
            NEW.order_id,
            delivery_status,
            CASE
                WHEN total_orders > 1 THEN 'Yes'
                ELSE 'No'
            END
        );

    END IF;

END//

DELIMITER ;


SELECT * FROM Customer_Retention;

SELECT
    order_id,
    customer_id,
    order_status
FROM Orders
WHERE order_status IN ('returned','cancelled')
LIMIT 1;


UPDATE Orders
SET order_status = 'delivered',
    order_delivered_customer_date = CURDATE()
WHERE order_id = 'O00003';


SELECT *
FROM Customer_Retention;