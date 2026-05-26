drop extension if exists "pg_net";

create type "public"."bwf_tour_level" as enum ('FINALS', 'SUPER_1000', 'SUPER_750', 'SUPER_500', 'SUPER_300');

create sequence "public"."bwf_tournaments_id_seq";


  create table "public"."bwf_tournaments" (
    "id" bigint not null default nextval('public.bwf_tournaments_id_seq'::regclass),
    "tournament_id" integer not null,
    "code" text,
    "name" text not null,
    "tour_level" public.bwf_tour_level not null,
    "category_id" integer not null,
    "start_date" date,
    "end_date" date,
    "date_label" text,
    "country" text,
    "location" text,
    "prize_money_usd" numeric(12,2),
    "detail_url" text,
    "flag_url" text,
    "logo_url" text,
    "cat_logo_url" text,
    "status" text,
    "has_live_scores" boolean,
    "year" integer not null,
    "raw" jsonb not null default '{}'::jsonb,
    "crawled_at" timestamp with time zone not null default now()
      );


alter table "public"."bwf_tournaments" enable row level security;

alter table "public"."batch_logs" enable row level security;

alter table "public"."bwf_rankings" enable row level security;

alter sequence "public"."bwf_tournaments_id_seq" owned by "public"."bwf_tournaments"."id";

CREATE UNIQUE INDEX bwf_tournaments_pkey ON public.bwf_tournaments USING btree (id);

CREATE INDEX bwf_tournaments_start_date_idx ON public.bwf_tournaments USING btree (start_date);

CREATE INDEX bwf_tournaments_tour_level_idx ON public.bwf_tournaments USING btree (tour_level);

CREATE UNIQUE INDEX bwf_tournaments_tournament_id_key ON public.bwf_tournaments USING btree (tournament_id);

CREATE INDEX bwf_tournaments_year_idx ON public.bwf_tournaments USING btree (year);

alter table "public"."bwf_tournaments" add constraint "bwf_tournaments_pkey" PRIMARY KEY using index "bwf_tournaments_pkey";

alter table "public"."bwf_tournaments" add constraint "bwf_tournaments_tournament_id_key" UNIQUE using index "bwf_tournaments_tournament_id_key";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

grant delete on table "public"."bwf_tournaments" to "anon";

grant insert on table "public"."bwf_tournaments" to "anon";

grant references on table "public"."bwf_tournaments" to "anon";

grant select on table "public"."bwf_tournaments" to "anon";

grant trigger on table "public"."bwf_tournaments" to "anon";

grant truncate on table "public"."bwf_tournaments" to "anon";

grant update on table "public"."bwf_tournaments" to "anon";

grant delete on table "public"."bwf_tournaments" to "authenticated";

grant insert on table "public"."bwf_tournaments" to "authenticated";

grant references on table "public"."bwf_tournaments" to "authenticated";

grant select on table "public"."bwf_tournaments" to "authenticated";

grant trigger on table "public"."bwf_tournaments" to "authenticated";

grant truncate on table "public"."bwf_tournaments" to "authenticated";

grant update on table "public"."bwf_tournaments" to "authenticated";

grant delete on table "public"."bwf_tournaments" to "service_role";

grant insert on table "public"."bwf_tournaments" to "service_role";

grant references on table "public"."bwf_tournaments" to "service_role";

grant select on table "public"."bwf_tournaments" to "service_role";

grant trigger on table "public"."bwf_tournaments" to "service_role";

grant truncate on table "public"."bwf_tournaments" to "service_role";

grant update on table "public"."bwf_tournaments" to "service_role";


