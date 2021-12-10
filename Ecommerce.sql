use mavenfuzzyfactory;
select * from orders;
select * from order_item_refunds;
select * from products;
select * from website_pageviews;
select * from website_sessions;


# Show the count of sessions of the utm sources, and the respective orders placed
select utm_source, count(distinct website_sessions.website_session_id) AS sessions, count(distinct orders.order_id) AS orders
from website_sessions
left join orders
on website_sessions.website_session_id = orders.website_session_id
where website_sessions.website_session_id between 1000 and 2000 -- arbitrary numbers
group by utm_source
order by 3 desc; # 3 means the 3rd column we input in the select statement, this is a shortcut, rather than writing count(distinct orders.order_id)


-- Sec 1:  Breakdown of where the bulk of website sessions are coming from
select utm_source, utm_campaign, http_referer, count(distinct website_session_id) AS sessions
from website_sessions
where created_at < '2012-04-12'
group by utm_source, utm_campaign, http_referer;


-- Sec 2:  Show the conversion rate from sessions to order for Gsearch & Non Brand combination
select
      count(distinct website_sessions.website_session_id) AS sessions,
      count(orders.order_id) AS orders,
      count(orders.order_id)/count(distinct website_sessions.website_session_id) AS conv_rate
from website_sessions
left join orders
on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at < '2012-04-14'
and utm_source = 'gsearch' and utm_campaign = 'nonbrand';


-- Sec 3: Show the drop in session counts on week by week basis after bid reduction.
select
      WEEK(created_at),
      MIN(DATE(created_at)) AS week_start,
      count(distinct website_sessions.website_session_id) AS sessions
from website_sessions
where website_sessions.created_at < '2012-05-10'
and utm_source = 'gsearch' and utm_campaign = 'nonbrand'
group by 1;


-- Sec 4: Show the session to order conversion rates based on device type
select device_type,
      count(distinct website_sessions.website_session_id) AS sessions,
      count(orders.order_id) AS orders,
      count(orders.order_id)/count(distinct website_sessions.website_session_id) AS conv_rate
from website_sessions
left join orders
on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at < '2012-05-11'
and utm_source = 'gsearch' and utm_campaign = 'nonbrand'
group by 1;


-- Sec 5: Weekly trends of desktop and mobile sessions post bid optimisation.
select
WEEK(created_at),
MIN(DATE(created_at)) AS week_start,
count(distinct CASE when device_type = 'desktop' then website_session_id else NULL END) AS desktop_sessions,
count(distinct CASE when device_type = 'mobile' then website_session_id else NULL END) AS mobile_sessions
from website_sessions
where website_sessions.created_at < '2012-06-09'
and website_sessions.created_at > '2012-04-15'
and utm_source = 'gsearch' and utm_campaign = 'nonbrand'
group by 1;


-- Sec 6: Find top pages and their views
select pageview_url,
	   count(Distinct website_pageview_id) as pageviews
from website_pageviews
where created_at < '2012-06-09'
group by pageview_url
order by pageviews DESC;


-- Sec 7: Find top entry pages and their sessions

-- step 1 : find the first pageview of each session
-- step 2 : find the url the user saw on that pageview

Create temporary table firstpage_view
select website_session_id,
	   min(website_pageview_id) AS min_pv
from website_pageviews
where created_at < '2012-06-12'
group by website_session_id;  
       
select * from firstpage_view;

select
website_pageviews.pageview_url AS landing_page_url,
COUNT(Distinct firstpage_view.website_session_id) AS sessions_hitting_page
From firstpage_view
left join website_pageviews
on firstpage_view.min_pv = website_pageviews.website_pageview_id
Group by website_pageviews.pageview_url;


-- Sec 8: find the sessions, bounced sessions and bounced rate of the homepage.

-- step 1: find the first pageview of each session
-- step 2 : find the landing pages of those sessions
-- step 3: counting pageviews of each session, to know the bounces
-- summarizing by counting total sessions and bounced sessions

Create temporary table firstpage_views
select website_session_id,
	   min(website_pageview_id) AS min_pv
from website_pageviews
where created_at < '2012-06-14'
group by website_session_id;

select * from firstpage_views;

Create temporary table sessions_with_only_home_landing_page
select
website_pageviews.pageview_url AS landing_page_url,
firstpage_views.website_session_id
From firstpage_views
left join website_pageviews
on firstpage_views.min_pv = website_pageviews.website_pageview_id
where website_pageviews.pageview_url = '/home';

select * from sessions_with_only_home_landing_page;

Create temporary table bounced_sessions
select
sessions_with_only_home_landing_page.landing_page_url,
sessions_with_only_home_landing_page.website_session_id,
COUNT(website_pageviews.website_pageview_id) AS pageviews
From sessions_with_only_home_landing_page
left join website_pageviews
on sessions_with_only_home_landing_page.website_session_id = website_pageviews.website_session_id
Group by sessions_with_only_home_landing_page.website_session_id,
sessions_with_only_home_landing_page.landing_page_url
Having COUNT(website_pageviews.website_pageview_id) = 1;

select * from bounced_sessions;

select
COUNT(distinct sessions_with_only_home_landing_page.website_session_id) AS sessions,
COUNT(distinct bounced_sessions.website_session_id) AS bounced_sessions,
COUNT(distinct bounced_sessions.website_session_id)/COUNT(distinct sessions_with_only_home_landing_page.website_session_id) As bounce_rate
From sessions_with_only_home_landing_page
left join bounced_sessions
on sessions_with_only_home_landing_page.website_session_id = bounced_sessions.website_session_id;


-- Sec 9: Find the search nonbrand traffic on pages /home, and /lander-1, and overall bounce rate for the same weekly.

-- Step 1: find the website_pageview_id of the relevant sessions
-- Step 2: Same drill, find the first pageview of the session, and then the landing page of the session
-- Step 3: Summarize it with bounce rate, and group them weekly.alter

Create temporary table sessions_w_min_pv_id_and_view_count
Select
website_sessions.website_session_id,
MIN(website_pageviews.website_pageview_id) as first_pv,
COUNT(website_pageviews.website_pageview_id) as count_of_pageviews
From website_sessions
left join website_pageviews
on website_sessions.website_session_id = website_pageviews.website_session_id
where
website_sessions.created_at > '2012-06-01' -- asked by requestor
and website_sessions.created_at < '2012-08-31' -- date of email
and website_sessions.utm_source = 'gsearch'
and website_sessions.utm_campaign = 'nonbrand'
group by website_sessions.website_session_id;

select * from sessions_w_min_pv_id_and_view_count;

create temporary table sessions_w_lander_and_created_at
select 
sessions_w_min_pv_id_and_view_count.website_session_id,
sessions_w_min_pv_id_and_view_count.first_pv,
sessions_w_min_pv_id_and_view_count.count_of_pageviews,
website_pageviews.pageview_url as landing_page,
website_pageviews.created_at as session_created_at
from sessions_w_min_pv_id_and_view_count
left join website_pageviews
on sessions_w_min_pv_id_and_view_count.first_pv = website_pageviews.website_pageview_id;

select * from sessions_w_lander_and_created_at;

select
MIN(DATE(session_created_at)) as week_start_date,
COUNT(Distinct CASE when count_of_pageviews = 1 then website_session_id ELSE null END)/COUNT(distinct website_session_id) as bounce_rate, -- bounce rate formula basically
COUNT(Distinct CASE when landing_page = '/home' then website_session_id ELSE null END) as home_sessions,
COUNT(Distinct CASE when landing_page = '/lander-1' then website_session_id ELSE null END) as lander1_sessions
From sessions_w_lander_and_created_at
group by YEARWEEK(session_created_at);


-- Sec 10: A conversion funnel analyzing how many customers make it to each step, for gsearch. Start with /lander-1 and end at thank you page.

-- Step 1: Only take sessions and the relevant pageviews
-- Step 2: Now for those sessions, check the pageview urls for each session and bring the data grouped by session, and the resp pageview urls it parsed.
-- Step 3: Aggregate the data using count to present it in a conversion funnel view.

Select
website_sessions.website_session_id,
website_pageviews.pageview_url,
Case when pageview_url = '/products' then 1 else 0 end as products_page,
Case when pageview_url = '/the-original-mr-fuzzy' then 1 else 0 end as mrfuzzy_page,
Case when pageview_url = '/cart' then 1 else 0 end as cart_page,
Case when pageview_url = '/shipping' then 1 else 0 end as shipping_page,
Case when pageview_url = '/billing' then 1 else 0 end as billing_page,
Case when pageview_url = '/thank-you-for-your-order' then 1 else 0 end as thankyou_page
from website_sessions
left join website_pageviews
on website_sessions.website_session_id = website_pageviews.website_session_id
where website_sessions.utm_source = 'gsearch'
and website_sessions.utm_campaign = 'nonbrand'
and website_sessions.created_at > '2012-08-05'
and website_sessions.created_at < '2012-09-05'
order by website_sessions.website_session_id, website_sessions.created_at;

-- now use this query as a sub-query and create a temporary table (for long multi step analysis, use temporary tables only.
-- otherwise, we can use sub-queries for short analysis of 2 steps max.)

create temporary table session_level_made_it
select
website_session_id,
max(products_page) as product_made_it,
max(mrfuzzy_page) as mrfuzzy_page_made_it,
max(cart_page) as cart_page_made_it,
max(shipping_page) as shipping_page_made_it,
max(billing_page) as billing_page_made_it,
max(thankyou_page) as thankyou_page_made_it
from(
Select
website_sessions.website_session_id,
website_pageviews.pageview_url,
Case when pageview_url = '/products' then 1 else 0 end as products_page,
Case when pageview_url = '/the-original-mr-fuzzy' then 1 else 0 end as mrfuzzy_page,
Case when pageview_url = '/cart' then 1 else 0 end as cart_page,
Case when pageview_url = '/shipping' then 1 else 0 end as shipping_page,
Case when pageview_url = '/billing' then 1 else 0 end as billing_page,
Case when pageview_url = '/thank-you-for-your-order' then 1 else 0 end as thankyou_page
from website_sessions
left join website_pageviews
on website_sessions.website_session_id = website_pageviews.website_session_id
where website_sessions.utm_source = 'gsearch'
and website_sessions.utm_campaign = 'nonbrand'
and website_sessions.created_at > '2012-08-05'
and website_sessions.created_at < '2012-09-05'
order by website_sessions.website_session_id, website_sessions.created_at) as pageview_level
group by website_session_id;

select * from session_level_made_it;

-- now aggregate the data to produce final output
select
count(distinct website_session_id) as sessions,
count(distinct case when product_made_it = 1 then website_session_id else null end) as to_products,
count(distinct case when mrfuzzy_page_made_it = 1 then website_session_id else null end) as to_mrfuzzy,
count(distinct case when cart_page_made_it = 1 then website_session_id else null end) as to_cart,
count(distinct case when shipping_page_made_it = 1 then website_session_id else null end) as to_shipping,
count(distinct case when billing_page_made_it = 1 then website_session_id else null end) as to_billing,
count(distinct case when thankyou_page_made_it = 1 then website_session_id else null end) as to_thankyou
from session_level_made_it;

-- to get click_through data
select
count(distinct case when product_made_it = 1 then website_session_id else null end)/count(distinct website_session_id) as lander_ctr,
count(distinct case when mrfuzzy_page_made_it = 1 then website_session_id else null end)/count(distinct case when product_made_it = 1 then website_session_id else null end) as product_ctr,
count(distinct case when cart_page_made_it = 1 then website_session_id else null end)/count(distinct case when mrfuzzy_page_made_it = 1 then website_session_id else null end) as mrfuzzy_ctr,
count(distinct case when shipping_page_made_it = 1 then website_session_id else null end)/count(distinct case when cart_page_made_it = 1 then website_session_id else null end) as cart_ctr,
count(distinct case when billing_page_made_it = 1 then website_session_id else null end)/count(distinct case when shipping_page_made_it = 1 then website_session_id else null end) as shipping_ctr,
count(distinct case when thankyou_page_made_it = 1 then website_session_id else null end)/count(distinct case when billing_page_made_it = 1 then website_session_id else null end) as billing_ctr
from session_level_made_it;










