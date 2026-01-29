CREATE DATABASE netflix_db;
USE netflix_db;

CREATE TABLE netflix_data (
    User_ID INT,
    User_Age INT,
    Age_Group VARCHAR(50),
    Gender VARCHAR(10),
    Country VARCHAR(50),
    Subscription_Type VARCHAR(50),
    Payment_Method VARCHAR(50),
    Revenue_INR DECIMAL(10,2),
    Churn_Flag TINYINT,
    Signup_Device VARCHAR(50),
    Show_Title VARCHAR(255),
    Genre VARCHAR(50),
    Rating DECIMAL(3,2),
    Watch_Hours DECIMAL(6,2),
    Duration_Watched_Min INT,
    Total_Duration_Min INT,
    Completion_Percentage DECIMAL(5,2),
    Login_Frequency_Per_Week DECIMAL(4,2),
    Avg_Session_Minutes DECIMAL(5,2),
    Viewing_Device VARCHAR(50),
    User_Rating DECIMAL(3,2),
    Customer_Satisfaction DECIMAL(3,2),
    Date DATE
);
SHOW VARIABLES LIKE 'secure_file_priv';

ALTER TABLE netflix_data
MODIFY Date VARCHAR(20);

TRUNCATE TABLE netflix_data;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Netflix_Cleaned_Analytics_File.csv'
INTO TABLE netflix_data
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    User_ID,
    User_Age,
    Age_Group,
    Gender,
    Country,
    Subscription_Type,
    Payment_Method,
    Revenue_INR,
    Churn_Flag,
    Signup_Device,
    Show_Title,
    Genre,
    Rating,
    Watch_Hours,
    Duration_Watched_Min,
    Total_Duration_Min,
    Completion_Percentage,
    Login_Frequency_Per_Week,
    Avg_Session_Minutes,
    Viewing_Device,
    User_Rating,
    @raw_customer_satisfaction,
    @raw_date
)
SET
    Customer_Satisfaction =
        CASE
            WHEN @raw_customer_satisfaction REGEXP '^[0-9]+$'
                 AND @raw_customer_satisfaction BETWEEN 1 AND 5
            THEN @raw_customer_satisfaction
            ELSE NULL
        END,
    Date = STR_TO_DATE(@raw_date, '%d-%m-%Y');

SELECT COUNT(*) FROM netflix_data;

SELECT Customer_Satisfaction
FROM netflix_data
WHERE Customer_Satisfaction IS NULL;

SELECT * FROM netflix_data;
-----------------------------------------------------------------------------------------------
----1.Total Revenue by Subscription Type
-----------------------------------------------------------------------------------------------

SELECT 
    Subscription_Type,
    SUM(Revenue_INR) AS Total_Revenue
FROM netflix_data
GROUP BY Subscription_Type
ORDER BY Total_Revenue DESC;

-----------------------------------------------------------------------------------------------
----2.Churn Rate by Subscription Type
-----------------------------------------------------------------------------------------------
SELECT
    Subscription_Type,
    ROUND(SUM(Churn_Flag) * 100.0 / COUNT(*), 2) AS Churn_Rate_Percent
FROM netflix_data
GROUP BY Subscription_Type;

-----------------------------------------------------------------------------------------------
----3.Revenue Lost Due to Churn
-----------------------------------------------------------------------------------------------
SELECT
    SUM(Revenue_INR) AS Revenue_Lost
FROM netflix_data
WHERE Churn_Flag = 1;

-----------------------------------------------------------------------------------------------
----4.Average Completion % by Genre
-----------------------------------------------------------------------------------------------
SELECT
    Genre,
    ROUND(AVG(Completion_Percentage), 2) AS Avg_Completion
FROM netflix_data
GROUP BY Genre
ORDER BY Avg_Completion DESC;

-----------------------------------------------------------------------------------------------
----5.Most Watched Shows (by Watch Hours)
-----------------------------------------------------------------------------------------------
SELECT
    Show_Title,
    SUM(Watch_Hours) AS Total_Watch_Hours
FROM netflix_data
GROUP BY Show_Title
ORDER BY Total_Watch_Hours DESC
LIMIT 10;

-----------------------------------------------------------------------------------------------
----6.Churn Rate by Viewing Device
-----------------------------------------------------------------------------------------------
SELECT
    Viewing_Device,
    ROUND(SUM(Churn_Flag) * 100.0 / COUNT(*), 2) AS Churn_Rate
FROM netflix_data
GROUP BY Viewing_Device;

-----------------------------------------------------------------------------------------------
----7. Avg Session Time by Subscription Type
-----------------------------------------------------------------------------------------------
SELECT
    Subscription_Type,
    ROUND(AVG(Avg_Session_Minutes), 2) AS Avg_Session_Min
FROM netflix_data
GROUP BY Subscription_Type;

-----------------------------------------------------------------------------------------------
----8.Customer Satisfaction vs Churn
-----------------------------------------------------------------------------------------------
SELECT
    Customer_Satisfaction,
    COUNT(*) AS Users,
    ROUND(SUM(Churn_Flag) * 100.0 / COUNT(*), 2) AS Churn_Rate
FROM netflix_data
GROUP BY Customer_Satisfaction
ORDER BY Customer_Satisfaction;

-----------------------------------------------------------------------------------------------
----9.Revenue by Country
-----------------------------------------------------------------------------------------------
SELECT
    Country,
    SUM(Revenue_INR) AS Total_Revenue
FROM netflix_data
GROUP BY Country
ORDER BY Total_Revenue DESC;

-----------------------------------------------------------------------------------------------
----10. Most Engaged Age Group
-----------------------------------------------------------------------------------------------
SELECT
    Age_Group,
    ROUND(AVG(Watch_Hours), 2) AS Avg_Watch_Hours
FROM netflix_data
GROUP BY Age_Group
ORDER BY Avg_Watch_Hours DESC;

-----------------------------------------------------------------------------------------------
----11.Power Users (Top 5%)
-----------------------------------------------------------------------------------------------
SELECT *
FROM (
    SELECT *,
           NTILE(20) OVER (ORDER BY Watch_Hours DESC) AS bucket
    FROM netflix_data
) t
WHERE bucket = 1;

-----------------------------------------------------------------------------------------------
----12.Login Frequency vs Completion Rate
-----------------------------------------------------------------------------------------------
SELECT
    Login_Frequency_Per_Week,
    ROUND(AVG(Completion_Percentage), 2) AS Avg_Completion
FROM netflix_data
GROUP BY Login_Frequency_Per_Week
ORDER BY Login_Frequency_Per_Week;

-----------------------------------------------------------------------------------------------
----13.Device Used for Signup vs Watching
-----------------------------------------------------------------------------------------------
SELECT
    Signup_Device,
    Viewing_Device,
    COUNT(*) AS Users
FROM netflix_data
GROUP BY Signup_Device, Viewing_Device
ORDER BY Users DESC;

-----------------------------------------------------------------------------------------------
----14.Monthly Revenue Trend
-----------------------------------------------------------------------------------------------
SELECT
    DATE_FORMAT(Date, '%Y-%m') AS Month,
    SUM(Revenue_INR) AS Monthly_Revenue
FROM netflix_data
GROUP BY Month
ORDER BY Month;

-----------------------------------------------------------------------------------------------
----15.Shows with High Rating but Low Completion
-----------------------------------------------------------------------------------------------
SELECT
    Show_Title,
    ROUND(AVG(Rating), 2) AS Avg_Rating,
    ROUND(AVG(Completion_Percentage), 2) AS Avg_Completion
FROM netflix_data
GROUP BY Show_Title
HAVING Avg_Rating >= 3 AND Avg_Completion < 2;

-----------------------------------------------------------------------------------------------
----16.Churn Rate by Subscription Type (CTE)
-----------------------------------------------------------------------------------------------

WITH churn_stats AS (
    SELECT
        Subscription_Type,
        COUNT(*) AS total_users,
        SUM(Churn_Flag) AS churned_users
    FROM netflix_data
    GROUP BY Subscription_Type
)
SELECT
    Subscription_Type,
    total_users,
    churned_users,
    ROUND(churned_users * 100.0 / total_users, 2) AS churn_rate_pct
FROM churn_stats
ORDER BY churn_rate_pct DESC;

-----------------------------------------------------------------------------------------------
----17.Revenue Contribution by Country (Window Function)
-----------------------------------------------------------------------------------------------
WITH country_revenue AS (
    SELECT
        Country,
        SUM(Revenue_INR) AS country_revenue
    FROM netflix_data
    GROUP BY Country
)
SELECT
    Country,
    country_revenue,
    ROUND(
        country_revenue * 100.0 / SUM(country_revenue) OVER (),
        2
    ) AS revenue_share_pct
FROM country_revenue
ORDER BY country_revenue DESC;

-----------------------------------------------------------------------------------------------
----18.Identify High-Value Power Users (NTILE)
-----------------------------------------------------------------------------------------------
WITH user_watch_bucket AS (
    SELECT
        User_ID,
        Watch_Hours,
        NTILE(20) OVER (ORDER BY Watch_Hours DESC) AS watch_bucket
    FROM netflix_data
)
SELECT
    User_ID,
    Watch_Hours
FROM user_watch_bucket
WHERE watch_bucket = 1;

-----------------------------------------------------------------------------------------------
----19.Monthly Revenue Trend + Growth (Window)
-----------------------------------------------------------------------------------------------

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(Date, '%Y-%m') AS month,
        SUM(Revenue_INR) AS revenue
    FROM netflix_data
    GROUP BY month
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0 /
        LAG(revenue) OVER (ORDER BY month),
        2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;

-----------------------------------------------------------------------------------------------
----20.Churn Risk by Customer Satisfaction (Ranking)
-----------------------------------------------------------------------------------------------
WITH satisfaction_churn AS (
    SELECT
        Customer_Satisfaction,
        COUNT(*) AS total_users,
        SUM(Churn_Flag) AS churned_users,
        ROUND(SUM(Churn_Flag) * 100.0 / COUNT(*), 2) AS churn_rate
    FROM netflix_data
    GROUP BY Customer_Satisfaction
)
SELECT
    Customer_Satisfaction,
    churn_rate,
    RANK() OVER (ORDER BY churn_rate DESC) AS churn_risk_rank
FROM satisfaction_churn;
