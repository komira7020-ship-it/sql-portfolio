-–розрахунок метрик по аккаунтам
With account_stats as(
 SELECT
      s.date as date,
      country,
      send_interval,
      is_verified,
      is_unsubscribed,
  count(distinct acc.id) as account_cnt,
  0 as sent_msg,
  0 as open_msg,
  0 as visit_msg
   
from `DA.account` acc  
join `DA.account_session` acs    
on acc.id=acs.account_id
join `DA.session` s    
on acs.ga_session_id=s.ga_session_id
join `DA.session_params` sp    
on acs.ga_session_id=sp.ga_session_id
group by 1,2,3,4,5
),
-–отримання інформації про відправлені, відкриті та відвідані листи 
email_stats as (
select
date_add(s.date, INTERVAL es.sent_date DAY) as date,
sp.country,
acc.send_interval,
acc.is_verified,
acc.is_unsubscribed,
0 as account_cnt,
count(distinct es.id_message) as sent_msg,
count(distinct eo.id_message) as open_msg,
count(distinct ev.id_message) as visit_msg
FROM `DA.email_sent` es
    LEFT JOIN `DA.email_open` eo
        ON es.id_message = eo.id_message
    LEFT JOIN `DA.email_visit` ev
        ON es.id_message = ev.id_message
  join `DA.account` acc
  on es.id_account=acc.id    
  join  `DA.account_session` acs
  on es.id_account=acs.account_id
  join  `DA.session` s  
  on acs.ga_session_id=s.ga_session_id
  join  `DA.session_params` sp
  on s.ga_session_id=sp.ga_session_id  
group by 1,2,3,4,5
),


-–результати з account_stats та email_stats об'єднуються за допомогою оператора UNION ALL.
–Використовується саме UNION ALL, оскільки потрібно зберегти всі рядки та не видаляти дублікати автоматично.


union_date as (
select *
from account_stats
union all
select *
from email_stats
),
aggregate_date as (
select
date,
country,
send_interval,
is_verified,
is_unsubscribed,
SUM(account_cnt) AS account_cnt,
 SUM(sent_msg) AS sent_msg,
  SUM(open_msg) AS open_msg,
  SUM(visit_msg) AS visit_msg
from union_date  
group by 1,2,3,4,5  
),
-–розраховуються загальні показники по країнах 
country_stats as(
select *,
sum(account_cnt) over (partition by country) as total_country_account_cnt,
sum(sent_msg) over (partition by country) as total_country_sent_cnt
from aggregate_date
),
-–формуємо рейтинг
ranked_date as(
select *,
dense_rank() over(order by total_country_account_cnt desc) as rank_total_country_account_cnt,
dense_rank() over(order by total_country_sent_cnt desc) as rank_total_country_sent_cnt
from country_stats
)
select *
from ranked_date
where rank_total_country_account_cnt<=10 or rank_total_country_sent_cnt<=10select distinct
  country,
  total_country_account_cnt,
  total_country_sent_cnt,
  rank_total_country_account_cnt,
  rank_total_country_sent_cnt
from ranked_date
where rank_total_country_account_cnt <= 10
   or rank_total_country_sent_cnt <= 10
order by rank_total_country_account_cnt,
         rank_total_country_sent_cnt
