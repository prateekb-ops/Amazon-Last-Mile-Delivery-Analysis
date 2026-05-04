-- ====================================================================================
-- AMAZON LAST-MILE DELIVERY PERFORMANCE & DEFECT ANALYSIS
-- Author: Prateek Behera
-- RDBMS: MySQL
-- Description: SQL pipelines to extract, clean, and aggregate delivery data for SLA tracking.
-- ====================================================================================

USE amazon_logistics;

-- ------------------------------------------------------------------------------------
-- QUERY 1: Establishing the SLA Baseline (Overall Performance)
-- Categorizes orders as 'On-Time' or 'Defect' based on a 90-minute delivery SLA threshold.
-- ------------------------------------------------------------------------------------
WITH SLA_Baseline AS (
    SELECT 
        Order_ID,
        Order_Date,
        Area,
        Traffic,
        Weather,
        Delivery_Time,
        CASE 
            WHEN Delivery_Time > 90 THEN 'Defect (Late)'
            ELSE 'On-Time' 
        END AS SLA_Status
    FROM delivery_data
    WHERE Delivery_Time IS NOT NULL
)
SELECT * FROM SLA_Baseline;


-- ------------------------------------------------------------------------------------
-- QUERY 2: Root Cause Defect Analysis 
-- Calculates the exact defect rate percentages caused by varying traffic and weather conditions.
-- ------------------------------------------------------------------------------------
WITH Defect_Counts AS (
    SELECT 
        Traffic,
        Weather,
        COUNT(Order_ID) AS Total_Orders,
        SUM(CASE WHEN Delivery_Time > 90 THEN 1 ELSE 0 END) AS Defect_Volume
    FROM delivery_data
    GROUP BY Traffic, Weather
)
SELECT 
    Traffic,
    Weather,
    Total_Orders,
    Defect_Volume,
    ROUND((Defect_Volume * 100.0) / Total_Orders, 2) AS Defect_Rate_Pct
FROM Defect_Counts
ORDER BY Defect_Rate_Pct DESC;


-- ------------------------------------------------------------------------------------
-- QUERY 3: Area Bottlenecks (Window Function)
-- Ranks product categories within each region by their average delivery time to isolate bottlenecks.
-- ------------------------------------------------------------------------------------
SELECT 
    Area,
    Category,
    ROUND(AVG(Delivery_Time), 2) AS Avg_Delivery_Time,
    RANK() OVER(PARTITION BY Area ORDER BY AVG(Delivery_Time) DESC) as Delay_Rank
FROM delivery_data
GROUP BY Area, Category;


-- ------------------------------------------------------------------------------------
-- QUERY 4: Agent Performance Variance (Complex JOIN)
-- Isolates specific deliveries that performed significantly worse than their baseline regional average.
-- ------------------------------------------------------------------------------------
WITH Area_Averages AS (
    SELECT 
        Area, 
        ROUND(AVG(Delivery_Time), 2) as Avg_Area_Time
    FROM delivery_data
    WHERE Delivery_Time IS NOT NULL
    GROUP BY Area
)
SELECT 
    d.Order_ID,
    d.Agent_Rating,
    d.Area,
    d.Weather,
    d.Traffic,
    d.Delivery_Time AS Actual_Time,
    a.Avg_Area_Time,
    (d.Delivery_Time - a.Avg_Area_Time) AS Minutes_Over_Average
FROM delivery_data d
JOIN Area_Averages a 
    ON d.Area = a.Area
WHERE d.Delivery_Time > a.Avg_Area_Time
ORDER BY Minutes_Over_Average DESC;