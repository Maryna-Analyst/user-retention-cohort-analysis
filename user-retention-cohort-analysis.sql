SELECT * FROM cohort_users_raw LIMIT 10;

SELECT * FROM cohort_events_raw LIMIT 10;

--очищення дат у cohort_users_raw:

with cleaned_users as (
		select 
			user_id, 
			promo_signup_flag,
		case 
			-- очищую пробіли, беру лише дату, замінюю . та / на -
			-- перевіряю довжину третьої частини (року)
			when length(split_part(regexp_replace (split_part (trim (signup_datetime), ' ', 1), '[./]', '-', 'g'), '-',03))= 2
			then to_date(regexp_replace (split_part (trim (signup_datetime), ' ', 1), '[./]', '-', 'g'), 'DD/MM/YY') ::timestamp
			else to_date(regexp_replace (split_part (trim (signup_datetime), ' ', 1), '[./]', '-', 'g'), 'DD/MM/YYYY') ::timestamp
			end as signup_datetime_timestamp
	from cohort_users_raw
	-- виключаю користувачів з відсутньою датою реєстрації:
	where signup_datetime is not null
	), 
cleaned_events as (
	select 
		user_id,
		event_id,
		event_type, 
		revenue,
		-- очищення дати події, як і в cleaned_users:
		case 
			when length(split_part(regexp_replace(split_part(trim(event_datetime), ' ', 1), '[./]', '-', 'g'), '-', 3)) = 2 
        	then to_date(regexp_replace(split_part(trim(event_datetime), ' ', 1), '[./]', '-', 'g'), 'DD-MM-YY')::timestamp
            else to_date(regexp_replace(split_part(trim(event_datetime), ' ', 1), '[./]', '-', 'g'), 'DD-MM-YYYY')::timestamp
        	end as event_datetime_timestamp
	from cohort_events_raw
	where
		-- виключаю події з відсутньою датою:
		event_datetime  is not null 
		-- виключаю події без типу:
		and event_type is not null 
		-- виключаю тестові події:
		and event_type != 'test_event'
	), 
joined_data as (
    select 
        u.user_id,
        u.promo_signup_flag,
        -- Місяць реєстрації (когорта)
        date_trunc('month', u.signup_datetime_timestamp)::date as cohort_month,
        -- Місяць події (активність)
        date_trunc('month', e.event_datetime_timestamp)::date as activity_month,
        extract(year from age(e.event_datetime_timestamp, u.signup_datetime_timestamp)) * 12 +
        extract(month from age(e.event_datetime_timestamp, u.signup_datetime_timestamp)) as month_offset
    from cleaned_users u
    join cleaned_events e on u.user_id = e.user_id
)
select 
    promo_signup_flag,
    cohort_month,
    month_offset,
    count(distinct user_id) as users_total
from joined_data
where activity_month between '2025-01-01' and '2025-06-30' -- Фільтр по місяцю активності
group by 1, 2, 3
order by 1, 2, 3;

