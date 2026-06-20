CREATE DATABASE Flipkart_Logistics;
USE Flipkart_Logistics;

SHOW TABLES;

-- Task 1  Data Cleaning & Preparation :
-- 1: Identify and delete duplicate Order_ID records.

SELECT
Order_ID,
COUNT(*) AS Total_Count
FROM flipkart_orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

-- 2: Replace null Traffic_Delay_Min with the average delay for that route. 
SELECT *
FROM flipkart_routes
WHERE Traffic_Delay_Min IS NULL;

SELECT COUNT(*) AS Null_Traffic_Delay
FROM flipkart_routes
WHERE Traffic_Delay_Min IS NULL;

-- 3:Convert all date columns into YYYY-MM-DD format using SQL functions. 
SELECT
Order_ID,
DATE_FORMAT(Order_Date,'%Y-%m-%d') AS Order_Date,
DATE_FORMAT(Expected_Delivery_Date,'%Y-%m-%d') AS Expected_Delivery_Date,
DATE_FORMAT(Actual_Delivery_Date,'%Y-%m-%d') AS Actual_Delivery_Date
FROM flipkart_orders
LIMIT 10;
-- 4:Ensure that no Actual_Delivery_Date is before Order_Date (flag such records). 
SELECT *
FROM flipkart_orders
WHERE Actual_Delivery_Date < Order_Date;


-- Task 2: Delivery Delay Analysis
-- 1: Calculate delivery delay (in days) for each order
SELECT
Order_ID,
Warehouse_ID,
Route_ID,
DATEDIFF(
Actual_Delivery_Date,
Expected_Delivery_Date
) AS Delay_Days
FROM flipkart_orders;

-- 2:Find Top 10 delayed routes based on average delay days.
SELECT
Route_ID,AVG(DATEDIFF(
Actual_Delivery_Date,
Expected_Delivery_Date
)
) AS Avg_Delay_Days
FROM flipkart_orders
GROUP BY Route_ID
ORDER BY Avg_Delay_Days DESC
LIMIT 10;

-- 3:Use window functions to rank all orders by delay within each warehouse. 
select 
order_id,warehouse_id, 
DATEDIFF(Actual_delivery_Date,Expected_Delivery_Date) 
As Delay_Days, 
Rank () over(partition by warehouse_id 
order by DATEDIFF(Actual_delivery_Date,Expected_Delivery_Date) 
DESC ) AS Delay_Rank
 from flipkart_orders;

commit;

-- Task 3 Route Optimization Insights:

-- 1. Average Delivery Time (in days)
SELECT
Route_ID,
AVG(DATEDIFF(Actual_Delivery_Date, Order_Date))
AS Avg_Delivery_Time_Days
FROM flipkart_orders
GROUP BY Route_ID;

-- 2. Average Traffic Delay
SELECT
Route_ID,
AVG(Traffic_Delay_Min)
AS Avg_Traffic_Delay
FROM flipkart_routes
GROUP BY Route_ID;

-- 3. Distance-to-Time Efficiency Ratio
SELECT
Route_ID,
Distance_KM,
Average_Travel_Time_Min,
ROUND(Distance_KM / Average_Travel_Time_Min,2) AS Efficiency_Ratio
FROM flipkart_routes;

-- 4. Identify 3 Routes with Worst Efficiency Ratio
SELECT
Route_ID,
ROUND(Distance_KM / Average_Travel_Time_Min,2) AS Efficiency_Ratio
FROM flipkart_routes
ORDER BY Efficiency_Ratio
LIMIT 3;

-- 5. Find Routes with >20% Delayed Shipments
SELECT
Route_ID,ROUND(100 *SUM(
CASE
WHEN Actual_Delivery_Date >Expected_Delivery_Date
THEN 1
ELSE 0
END)/ COUNT(*),2) AS Delay_Percentage
FROM flipkart_orders
GROUP BY Route_ID
HAVING Delay_Percentage > 20;

commit;
-- Task 4: Warehouse Performance
-- Find the top 3 warehouses with the highest average processing time.
SELECT
Warehouse_ID,
Warehouse_Name,
Average_Processing_Time_Min
FROM flipkart_warehouses
ORDER BY Average_Processing_Time_Min DESC
LIMIT 3;


-- 2: Total vs Delayed Shipments for Each Warehouse
SELECT
Warehouse_ID,
COUNT(*) AS Total_Shipments,
SUM(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date
THEN 1
ELSE 0
END) AS Delayed_Shipments
FROM flipkart_orders
GROUP BY Warehouse_ID;

-- 3. Bottleneck Warehouses Using CTE
WITH AvgProc AS
(SELECT AVG(Average_Processing_Time_Min) AS Global_Avg
FROM flipkart_warehouses)
SELECT
Warehouse_ID,
Warehouse_Name,
Average_Processing_Time_Min
FROM flipkart_warehouses, AvgProc
WHERE Average_Processing_Time_Min > Global_Avg;

-- 4. Rank Warehouses Based on On-Time Delivery Percentage
SELECT
Warehouse_ID,
ROUND(100 *
SUM(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date
THEN 1 ELSE 0 END)/ COUNT(*),2) AS OnTime_Percentage,
RANK() OVER(ORDER BY ROUND(100 *SUM(
CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date
THEN 1 ELSE 0 END)/ COUNT(*),2) DESC) AS Warehouse_Rank
FROM flipkart_orders
GROUP BY Warehouse_ID;

-- Task 5: Delivery Agent Performance 
-- 1. Rank Agents (per route) by On-Time Delivery Percentage
SELECT
Agent_ID,
Route_ID,
On_Time_Delivery_Percentage,
RANK() OVER(
PARTITION BY Route_ID
ORDER BY On_Time_Delivery_Percentage DESC
) AS Agent_Rank
FROM flipkart_deliveryagents;

-- 2. Find Agents with On-Time % < 80
SELECT *
FROM flipkart_deliveryagents
WHERE On_Time_Delivery_Percentage < 80;

-- 3. Top 5 Agent Average Speed
SELECT AVG(Avg_Speed_KMPH) AS Top5_Avg_Speed
FROM
(
SELECT Avg_Speed_KMPH
FROM flipkart_deliveryagents
ORDER BY On_Time_Delivery_Percentage DESC
LIMIT 5
) t;

-- 4. Bottom 5 Agent Average Speed
SELECT AVG(Avg_Speed_KMPH) AS Bottom5_Avg_Speed
FROM
(
SELECT Avg_Speed_KMPH
FROM flipkart_deliveryagents
ORDER BY On_Time_Delivery_Percentage ASC
LIMIT 5
) b;


-- Task 6
-- Task 1: Last Checkpoint and Time for Each Order
SELECT
Order_ID,
Checkpoint,
Checkpoint_Time
FROM flipkart_shipmenttracking s
WHERE Checkpoint_Time =
(SELECT MAX(Checkpoint_Time)
FROM flipkart_shipmenttracking s2
WHERE s2.Order_ID = s.Order_ID);

-- 2. Find the Most Common Delay Reasons (excluding None)
SELECT
Delay_Reason,
COUNT(*) AS Frequency
FROM flipkart_shipmenttracking
WHERE Delay_Reason <> 'None'
GROUP BY Delay_Reason
ORDER BY Frequency DESC;

-- Task 3: Orders with More Than 2 Delayed Checkpoints
SELECT
Order_ID,
COUNT(*) AS Delayed_Checkpoints
FROM flipkart_shipmenttracking
WHERE Delay_Minutes > 0
GROUP BY Order_ID
HAVING COUNT(*) > 2;

-- Task 7: Advanced KPI Reporting
-- 1. Average Delivery Delay per Region
SELECT
r.Start_Location,
AVG(DATEDIFF(
o.Actual_Delivery_Date,
o.Expected_Delivery_Date)) AS Avg_Delivery_Delay
FROM flipkart_orders o
JOIN flipkart_routes r
ON o.Route_ID = r.Route_ID
GROUP BY r.Start_Location;

-- 2. On-Time Delivery Percentage
SELECT
ROUND(100 *SUM(
CASE
WHEN Actual_Delivery_Date <= Expected_Delivery_Date
THEN 1 ELSE 0 END)
/ COUNT(*),2) AS OnTime_Delivery_Percentage
FROM flipkart_orders;

-- 3. Average Traffic Delay per Route
SELECT
Route_ID,
AVG(Traffic_Delay_Min) AS Avg_Traffic_Delay
FROM flipkart_routes
GROUP BY Route_ID;