{% macro buckets_cte(time_bucket) %}
    {{ adapter.dispatch('buckets_cte','elementary')(time_bucket) }}
{% endmacro %}

{# Databricks and Spark #}
{% macro default__buckets_cte(time_bucket) %}
    select edr_bucket
    from (select explode(sequence({{ elementary.cast_as_timestamp(elementary.quote(elementary.get_min_bucket_start())) }}, {{ elementary.cast_as_timestamp(elementary.quote(elementary.get_max_bucket_end())) }}, interval {{ time_bucket.count }} {{ time_bucket.period }})) AS edr_bucket)
{% endmacro %}

{% macro snowflake__buckets_cte(time_bucket) -%}
    {%- set buckets_cte %}
        with dates as (
            select {{ elementary.cast_as_timestamp(elementary.quote(elementary.get_min_bucket_start())) }} as date
        union all
        select {{ elementary.timeadd(time_bucket.period, time_bucket.count, 'date') }} as bucket_end
        from dates
        where bucket_end <= {{ elementary.cast_as_timestamp(elementary.quote(elementary.get_max_bucket_end())) }}
            )
        select date as edr_bucket
        from dates
    {%- endset %}
    {{ return(buckets_cte) }}
{% endmacro %}


{% macro bigquery__buckets_cte(time_bucket) %}
    {%- set buckets_cte %}
        select edr_bucket
        from unnest(generate_timestamp_array({{ elementary.cast_as_timestamp(elementary.quote(elementary.get_min_bucket_start())) }}, {{ elementary.cast_as_timestamp(elementary.quote(elementary.get_max_bucket_end())) }}, interval {{ time_bucket.count }} {{ time_bucket.period }})) as edr_bucket
    {%- endset %}
    {{ return(buckets_cte) }}
{% endmacro %}

{% macro redshift__buckets_cte(time_bucket) %}
    {%- set buckets_cte %}
      with integers as (
        select (row_number() over (order by 1)) - 1 as num
        from pg_catalog.pg_class
        limit {{ elementary.datediff(elementary.cast_as_timestamp(elementary.quote(elementary.get_min_bucket_start())), elementary.cast_as_timestamp(elementary.quote(elementary.get_max_bucket_end())), time_bucket.period) }} / {{ time_bucket.count }} + 1
      )
      select {{ elementary.cast_as_timestamp(elementary.quote(elementary.get_min_bucket_start())) }} + (num * interval '{{ time_bucket.count }} {{ time_bucket.period }}') as edr_bucket
      from integers
    {%- endset %}
    {{ return(buckets_cte) }}
{% endmacro %}
