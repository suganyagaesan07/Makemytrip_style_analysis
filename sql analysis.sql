create database makemytrip;
use makemytrip;
-- created cities table
CREATE TABLE cities (
    city_id    INT          NOT NULL PRIMARY KEY,
    city_name  VARCHAR(50)  NOT NULL UNIQUE,
    state      VARCHAR(50)  NOT NULL,
    city_tier  VARCHAR(10)  NOT NULL
               CHECK (city_tier IN ('Metro', 'Tier-1', 'Tier-2'))
);

-- customer table

CREATE TABLE customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(100),
    gender VARCHAR(20),
    age INT,
    email VARCHAR(150),
    home_city VARCHAR(100),
    signup_date VARCHAR(20),
    loyalty_tier VARCHAR(30)
);
ALTER TABLE customers
ADD COLUMN signup_date_new DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE customers
SET signup_date_new = STR_TO_DATE(signup_date, '%d-%m-%Y');

select * from customers;
-- create booking table

CREATE TABLE bookings (
    booking_id        VARCHAR(12)  NOT NULL,
    customer_id       VARCHAR(10)  NOT NULL,          -- NOT unique: one customer has many bookings
    booking_type      ENUM('Flights','Hotel','Bus','Train','Holiday Package') NOT NULL,
    booking_date      DATE         NOT NULL,
    travel_date       DATE         NOT NULL,
    source_city       VARCHAR(50)  NULL,
    destination_city  VARCHAR(50)  NULL,
    booking_channel   ENUM('Mobile App','Website','Agent') NOT NULL,
    num_travellers    TINYINT UNSIGNED NULL,
    base_amount       INT UNSIGNED NOT NULL,
    discount          INT UNSIGNED NULL,
    total_amount      INT UNSIGNED NOT NULL,
    booking_status    ENUM('Completed','Confirmed','Cancelled','Failed') NOT NULL,
    PRIMARY KEY (booking_id),
    KEY idx_customer (customer_id),
    KEY idx_booking_date (booking_date),
    KEY idx_status (booking_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE flight_details (
    flight_id     VARCHAR(10)  NOT NULL PRIMARY KEY,       -- e.g. F00001
    booking_id    VARCHAR(15)  NOT NULL UNIQUE,
    airline       VARCHAR(30),
    flight_class  VARCHAR(20),                             -- Economy | Premium Economy | Business
    stops         INT          CHECK (stops BETWEEN 0 AND 3),
    duration_min  DECIMAL(6,1)                             -- flight time in minutes (sheet column: duration_time)
);

 CREATE TABLE hotel_details (
    hotel_booking_id  VARCHAR(10)  NOT NULL,
    booking_id        VARCHAR(12)  NOT NULL,
    hotel_name        VARCHAR(60)  NOT NULL,
    hotel_city        VARCHAR(50)  NOT NULL,
    nights            TINYINT UNSIGNED NOT NULL,
    room_type         ENUM('Standard','Deluxe','Suite') NOT NULL,
    star_rating       TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (hotel_booking_id),
    UNIQUE KEY uq_hotel_booking (booking_id),
    CONSTRAINT fk_hotel_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id),
    CONSTRAINT chk_star CHECK (star_rating BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cancellations (
    cancellation_id   VARCHAR(10)  NOT NULL,
    booking_id        VARCHAR(12)  NOT NULL,
    cancel_date       DATE         NULL,
    cancel_reason     ENUM('Flight Rescheduled','Found Better Price','Payment Issue',
                           'Medical Emergency','Visa/Document Issue','Change Of Plans') NOT NULL,
    refund_amount     INT UNSIGNED NULL,
    PRIMARY KEY (cancellation_id),
    UNIQUE KEY uq_cancel_booking (booking_id),
    CONSTRAINT fk_cancel_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE cancellations (
    cancellation_id   VARCHAR(10)  NOT NULL,
    booking_id        VARCHAR(12)  NOT NULL,
    cancel_date       DATE         NULL,
    cancel_reason     ENUM('Flight Rescheduled','Found Better Price','Payment Issue',
                           'Medical Emergency','Visa/Document Issue','Change Of Plans') NOT NULL,
    refund_amount     INT UNSIGNED NULL,
    PRIMARY KEY (cancellation_id),
    UNIQUE KEY uq_cancel_booking (booking_id),
    CONSTRAINT fk_cancel_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE reviews (
    review_id         VARCHAR(10)  NOT NULL,
    booking_id        VARCHAR(12)  NOT NULL,
    review_date       DATE         NOT NULL,
    rating            TINYINT UNSIGNED NULL,
    PRIMARY KEY (review_id),
    UNIQUE KEY uq_review_booking (booking_id),
    CONSTRAINT fk_review_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id),
    CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE payments (
    payment_id        VARCHAR(10)  NOT NULL,
    booking_id        VARCHAR(12)  NOT NULL,
    payment_mode      ENUM('UPI','Credit Card','Debit Card','Net Banking','Wallet','EMI') NOT NULL,
    payment_status    ENUM('Success','Refunded','Failed') NOT NULL,
    payment_date      DATE         NOT NULL,
    amount_paid       INT UNSIGNED NOT NULL,           -- 0 for Failed payments
    PRIMARY KEY (payment_id),
    KEY idx_payment_booking (booking_id),
    KEY idx_payment_status (payment_status),
    CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


select max(booking_date) from bookings;
-- rfm analysis

CREATE OR REPLACE VIEW rfm_customer_segments AS

WITH rfm AS (
    SELECT 
        customer_id,
        DATEDIFF('2025-12-31', MAX(booking_date)) AS recency,
        COUNT(*) AS frequency,
        SUM(total_amount) AS monetary
    FROM bookings
    GROUP BY customer_id
),

rfm_scores AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,

        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score

    FROM rfm
)

SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,

    CASE
        WHEN r_score = 5 
             AND f_score = 5 
             AND m_score = 5
            THEN 'Champions'

        WHEN r_score >= 4 
             AND f_score >= 4 
             AND m_score >= 4
            THEN 'Loyal Customers'

        WHEN r_score >= 3 
             AND f_score >= 3
            THEN 'Potential Loyalists'

        WHEN r_score <= 2 
             AND f_score >= 3
            THEN 'At Risk'

        ELSE 'Lost Customers'
    END AS segment

FROM rfm_scores;

SELECT *
FROM rfm_customer_segments;


select segment ,count(*) as counts from rfm_customer_segments
group by segment;

-- page 1
-- Excutive summary

-- 1.How many total bookings were made?
select count(*) as total_bookings from bookings;

-- 2. What is the total booking revenue?
select sum(total_amount) as total_booking from bookings;

-- 3. What is the booking success rate?
select distinct(booking_status) from bookings;

select round(100*sum(booking_status='Completed')/count(*),2 ) as success_rate
from bookings;

-- 4. What is the average booking value?
select round(avg(total_amount) )as average_booking_value
from bookings;

-- 5.How has the number of bookings changed month by month?
select date_format(booking_date,"%Y-%m") as month,
count(*) as total_bookings from bookings
group by month
order by total_bookings desc;

-- 6.Which booking type generates the most revenue?
select booking_type ,sum(total_amount) as total_amount
from bookings
group by booking_type
order by total_amount desc;

-- 7. Which booking channel generates the most bookings?
select booking_channel,count(*) as total_bookings
from bookings
group by booking_channel
order by total_bookings desc;

-- page 2
-- customer rfm analysis

-- 1. How many unique customers are there?
select distinct(count(customer_id)) as total_customers
from customers;

-- 2.What is the average Recency, Frequency and Monetary value?
select avg(Recency) as avg_Recency,
avg(Frequency) as avg_Frequency,
avg(Monetary) as avg_monetary
from rfm_customer_segments;

-- 3. How many customers are in each RFM segment
select segment,count(*) as total_customer
from rfm_customer_segments
group by segment
order by total_customer;

-- 4. Who are our highest-value customers?
SELECT c.customer_name, r.monetary, r.frequency, r.recency, r.segment
FROM rfm_customer_segments r JOIN customers c USING (customer_id)
ORDER BY r.monetary DESC LIMIT 10;

-- 5.Which customer segments generate the most revenue?

select segment ,sum(monetary) as total_revenue
from rfm_customer_segments
group by segment
order by total_revenue desc;

-- 6.Which segments have the highest booking frequency?
select segment ,round(avg(frequency)) as avg_frequency
from rfm_customer_segments
group by segment
order by avg_frequency asc;

-- 7.Which customers are at risk of becoming inactive?
select c.customer_name,
c.home_city,
r.recency,
r.frequency,
r.monetary,
r.segment
from customers c join rfm_customer_segments r using(customer_id)
where segment in('At Risk','Lost Customers');

--  8.Which segments should we target for retention and upselling

SELECT segment, COUNT(*) AS customers, SUM(monetary) AS revenue,
       ROUND(100*SUM(monetary)/SUM(SUM(monetary)) OVER (),2) AS revenue_pct,
       ROUND(AVG(recency),0) AS avg_recency_days, ROUND(AVG(frequency),2) AS avg_frequency
FROM rfm_customer_segments GROUP BY segment ORDER BY revenue DESC;


-- page 3
-- Flight & Hotel Booking
-- 1. Which airline has the most bookings?
select airline,count(*) as total_bookings
from flight_details
group by airline;

-- 2. Which airline generates the highest revenue?
select f.airline,
sum(b.total_amount) as revenue from 
flight_details f join bookings b 
using(booking_id)
group by f.airline
order by revenue desc;

-- 3.Which flight class is most popular?
select flight_class,count(*) as total_booking
from flight_details
group by flight_class
order by total_booking desc;

-- 4.Which routes have the highest number of bookings?
select concat(source_city,'-',destination_city) as route,
count(*) as total_bookings
from bookings
group by route
order by total_bookings desc;

-- 5.Does the number of stops affect booking value?

SELECT f.stops,
 ROUND(AVG(b.total_amount),0) AS avg_value, 
 COUNT(*) AS bookings
FROM flight_details f JOIN bookings b USING(booking_id) 
GROUP BY f.stops ORDER BY f.stops;

-- hotel analysis
-- 6. Which hotel cities receive the most bookings?
select hotel_city,count(*) as total_bookings
from hotel_details
group by hotel_city
order by total_bookings desc;

-- 7. Which room type is most preferred?
select room_type,count(*) as total_preferred
from hotel_details
group by room_type
order by total_preferred desc;

-- 8.Which star rating is most popular?
SELECT h.star_rating, COUNT(*) AS bookings,
 ROUND(AVG(b.total_amount),0) AS avg_value
FROM hotel_details h JOIN bookings b USING(booking_id) 
GROUP BY h.star_rating ORDER BY h.star_rating;

-- 9. What is the average number of nights booked?
select avg(nights)as avg_nights
from hotel_details;

-- 10. Which room type generates the highest revenue?
select h.room_type,sum(b.total_amount) as revenue
from hotel_details h join bookings b using(booking_id)
group by room_type
order by revenue desc;

-- page 4
-- Cancellation & Payment Analysis

-- 1. What is the overall cancellation rate
select round(100*sum(booking_status='Cancelled')/count(*)) as cancellation_rate
from bookings;

-- 2. Which booking type has the highest cancellation rate?
select booking_type ,
round(100*sum(booking_status='Cancelled')/count(*)) as cancellation_rate
from bookings
group by booking_type;

-- 3. What are the most common cancellation reasons?
select cancel_reason,count(*) as total_cancellation
from cancellations
group by cancel_reason
order by total_cancellation desc;

-- 4. Which booking channel has the highest cancellation rate?
select booking_channel,
round(100*sum(booking_status='Cancelled')/count(*)) as cancellation_rate
from bookings
group by booking_channel ;

-- 5. How much revenue is lost because of cancellations?

select sum(total_amount) as lost_revenue
from bookings
where booking_status='cancelled';

-- 6. What is the total refund amount?
select sum(refund_amount) as total_refund_amount
from cancellations;

-- 7. Which payment mode is most commonly used?
select payment_mode,count(*) as total_counts
from payments
group by payment_mode
order by total_counts desc;

-- 8.What is the payment success rate?
select round(100*sum(payment_status='success')/count(*)) as payment_success_rate
from payments;

-- 9.Which payment mode has the highest failure rate?
select payment_mode,
round(100*sum(payment_status='failed')/count(*)) from payments
group by payment_mode;

-- 10.Monthly cancellation trend
select date_format(cancel_date,"%Y-%m") as month,
count(*)  as cancellations_counts from cancellations
group by month;


