CREATE OR REPLACE FUNCTION iron_lion_uuid() RETURNS uuid AS $$
BEGIN
  RETURN uuid_generate_v4();
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- CREATE SEQUENCE public.iron_lion_uuid_seq
--   START WITH 1
--   INCREMENT BY 1
--   NO MINVALUE
--   NO MAXVALUE
--   CACHE 1;

-- CREATE OR REPLACE FUNCTION public.iron_lion_uuid() RETURNS UUID
--   LANGUAGE plpgsql
--   AS $$
-- DECLARE
--   epoch BIGINT := 205617180;
--   now BIGINT;

--   tenant BIGINT := 47535134;
--   shard BIGINT := 1;
--   seq BIGINT;
--   key BIGINT;

--   large BIGINT;
--   small BIGINT;
-- BEGIN
--   now := (EXTRACT(EPOCH FROM clock_timestamp() AT TIME ZONE 'utc') - epoch) * 1000000;
--   seq := NEXTVAL('public.iron_lion_uuid_seq') & 1023;

--   key := (RANDOM() * #{TUID.limit(:key) + 1})::BIGINT;
--   key := (key << #{TUID::KEY_SIZE}) | key;

--   tenant := (tenant # key) & #{TUID.limit(:operator)};
--   shard := (shard # key) & #{TUID.limit(:shard)};

--   large := now << #{TUID::TIME_POS - 64};
--   large := large | (tenant >> #{TUID::OPERATOR_SIZE - (TUID::TIME_POS - 64)});

--   small := tenant << #{TUID::OPERATOR_POS};
--   small := small | (shard << #{TUID::SHARD_POS});
--   small := small | (seq << #{TUID::SEQ_POS});
--   small := small | (key & #{TUID.limit(:key)});

--   RETURN (
--     LPAD(TO_HEX(large), 16, '0') ||
--     LPAD(TO_HEX(small), 16, '0')
--   )::UUID;
-- END;
-- $$;
