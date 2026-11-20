-- IronLion helper functions. They do not depend on the format, so every
-- install recreates them unchanged. Encodings mirror lib/iron_lion exactly.

CREATE SEQUENCE IF NOT EXISTS iron_lion_seq;

-- The database's answer for a field, like ENV["IRON_LION_TENANT"] in Ruby:
--   ALTER DATABASE app SET iron_lion.node = '53';   or   SET LOCAL iron_lion.tenant = '7';
CREATE OR REPLACE FUNCTION iron_lion_setting(field text) RETURNS text
LANGUAGE sql STABLE AS $iron_lion$
  SELECT nullif(current_setting('iron_lion.' || field, true), '')
$iron_lion$;

CREATE OR REPLACE FUNCTION iron_lion_missing(field text) RETURNS void
LANGUAGE plpgsql AS $iron_lion$
BEGIN
  RAISE EXCEPTION 'No value for %. IronLion looked in: iron_lion_uuid(% => ...), the row''s columns '
                  '(when inserting), and the setting iron_lion.%', field, field, field
    USING ERRCODE = 'not_null_violation';
END
$iron_lion$;

-- A non-negative integer as exactly `width` bits.
CREATE OR REPLACE FUNCTION iron_lion_int_bits(value numeric, width integer, field text) RETURNS varbit
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _result varbit := B'';
  _remaining numeric := value;
BEGIN
  IF value IS NULL THEN
    PERFORM iron_lion_missing(field);
  END IF;

  IF value <> trunc(value) OR value < 0 OR value >= 2::numeric ^ width THEN
    RAISE EXCEPTION '% % does not fit in % bits (0..%)', field, value, width, round(2::numeric ^ width) - 1
      USING ERRCODE = 'numeric_value_out_of_range';
  END IF;

  FOR _i IN 1..ceil(width / 32.0) LOOP
    _result := (_remaining % 4294967296)::bigint::bit(32) || _result;
    _remaining := div(_remaining, 4294967296);
  END LOOP;

  RETURN substring(_result FROM length(_result) - width + 1);
END
$iron_lion$;

-- Bijective base 36, as IronLion::Base36.
CREATE OR REPLACE FUNCTION iron_lion_text_bits(value text, chars integer, width integer, field text)
RETURNS varbit
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _text text := lower(value);
  _number numeric := 0;
BEGIN
  IF value IS NULL THEN
    PERFORM iron_lion_missing(field);
  END IF;

  IF _text = '' THEN
    RAISE EXCEPTION '% "%" is blank', field, value USING ERRCODE = 'invalid_parameter_value';
  ELSIF length(_text) > chars THEN
    RAISE EXCEPTION '% "%" is longer than % characters', field, value, chars
      USING ERRCODE = 'invalid_parameter_value';
  ELSIF _text !~ '^[0-9a-z]+$' THEN
    RAISE EXCEPTION '% "%" may only contain letters and digits', field, value
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  FOR _i IN 1..length(_text) LOOP
    _number := _number * 36 + position(substr(_text, _i, 1) IN '0123456789abcdefghijklmnopqrstuvwxyz');
  END LOOP;

  RETURN iron_lion_int_bits(_number, width, field);
END
$iron_lion$;

-- An H3 cell (hex) at a fixed resolution: base cell + digits, as IronLion::H3.
CREATE OR REPLACE FUNCTION iron_lion_h3_bits(value text, resolution integer, field text) RETURNS varbit
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _hex text;
  _index bigint;
  _digits bigint;
BEGIN
  IF value IS NULL THEN
    PERFORM iron_lion_missing(field);
  END IF;

  _hex := regexp_replace(lower(btrim(value)), '^0x', '');
  IF _hex !~ '^[0-9a-f]{1,16}$' THEN
    RAISE EXCEPTION '% "%" is not an H3 index', field, value USING ERRCODE = 'invalid_parameter_value';
  END IF;

  _index := ('x' || lpad(_hex, 16, '0'))::bit(64)::bigint;

  IF _index < 0 OR ((_index >> 59) & 15) <> 1 OR ((_index >> 56) & 7) <> 0 OR ((_index >> 45) & 127) > 121 THEN
    RAISE EXCEPTION '% "%" is not an H3 cell index', field, value USING ERRCODE = 'invalid_parameter_value';
  END IF;

  IF ((_index >> 52) & 15) < resolution THEN
    RAISE EXCEPTION '% "%" is a resolution % cell, coarser than resolution %',
      field, value, (_index >> 52) & 15, resolution USING ERRCODE = 'invalid_parameter_value';
  END IF;

  _digits := (_index >> (3 * (15 - resolution))) & ((1::bigint << (3 * resolution)) - 1);

  FOR _i IN 0..resolution - 1 LOOP
    IF ((_digits >> (3 * _i)) & 7) = 7 THEN
      RAISE EXCEPTION '% "%" is not a valid H3 cell (digit % is 7)', field, value, resolution - _i
        USING ERRCODE = 'invalid_parameter_value';
    END IF;
  END LOOP;

  RETURN iron_lion_int_bits(
    ((((_index >> 45) & 127) << (3 * resolution)) | _digits)::numeric,
    7 + 3 * resolution,
    field
  );
END
$iron_lion$;

-- The geohash of a coordinate, as IronLion::Geohash. Exact for numeric input.
CREATE OR REPLACE FUNCTION iron_lion_geohash(latitude numeric, longitude numeric, chars integer) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _total integer := 5 * chars;
  _latitude_bits integer := _total / 2;
  _longitude_bits integer := _total - _total / 2;
  _latitude varbit;
  _longitude varbit;
  _bits varbit := B'';
  _result text := '';
BEGIN
  IF latitude IS NULL OR longitude IS NULL THEN
    RETURN NULL;
  ELSIF latitude < -90 OR latitude > 90 THEN
    RAISE EXCEPTION 'latitude % is outside -90..90', latitude USING ERRCODE = 'invalid_parameter_value';
  ELSIF longitude < -180 OR longitude > 180 THEN
    RAISE EXCEPTION 'longitude % is outside -180..180', longitude USING ERRCODE = 'invalid_parameter_value';
  END IF;

  _latitude := iron_lion_int_bits(
    least(div((latitude + 90) * 2::numeric ^ _latitude_bits, 180), 2::numeric ^ _latitude_bits - 1),
    _latitude_bits, 'latitude'
  );
  _longitude := iron_lion_int_bits(
    least(div((longitude + 180) * 2::numeric ^ _longitude_bits, 360), 2::numeric ^ _longitude_bits - 1),
    _longitude_bits, 'longitude'
  );

  FOR _i IN 0.._total - 1 LOOP
    IF _i % 2 = 0 THEN
      _bits := _bits || substring(_longitude FROM _i / 2 + 1 FOR 1);
    ELSE
      _bits := _bits || substring(_latitude FROM _i / 2 + 1 FOR 1);
    END IF;
  END LOOP;

  FOR _i IN 0..chars - 1 LOOP
    _result := _result ||
      substr('0123456789bcdefghjkmnpqrstuvwxyz', substring(_bits FROM 5 * _i + 1 FOR 5)::bit(5)::integer + 1, 1);
  END LOOP;

  RETURN _result;
END
$iron_lion$;

CREATE OR REPLACE FUNCTION iron_lion_geohash_bits(value text, chars integer, field text) RETURNS varbit
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _text text := lower(btrim(value));
  _bits varbit := B'';
BEGIN
  IF value IS NULL THEN
    PERFORM iron_lion_missing(field);
  END IF;

  IF _text !~ '^[0-9b-hjkmnp-z]+$' THEN
    RAISE EXCEPTION '% "%" is not a geohash', field, value USING ERRCODE = 'invalid_parameter_value';
  ELSIF length(_text) < chars THEN
    RAISE EXCEPTION '% "%" is a %-character geohash; % are needed', field, value, length(_text), chars
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  FOR _i IN 1..chars LOOP
    _bits := _bits || (position(substr(_text, _i, 1) IN '0123456789bcdefghjkmnpqrstuvwxyz') - 1)::bit(5);
  END LOOP;

  RETURN _bits;
END
$iron_lion$;

-- 122 secure random bits: everything in a v4 UUID except its version and variant.
CREATE OR REPLACE FUNCTION iron_lion_random_bits() RETURNS varbit
LANGUAGE plpgsql VOLATILE AS $iron_lion$
DECLARE
  _bits bit(128) := ('x' || replace(gen_random_uuid()::text, '-', ''))::bit(128);
BEGIN
  RETURN substring(_bits FROM 1 FOR 48) || substring(_bits FROM 53 FOR 12) || substring(_bits FROM 67 FOR 62);
END
$iron_lion$;

-- Places 122 payload bits around the UUIDv8 version and variant, as IronLion::Layout.
CREATE OR REPLACE FUNCTION iron_lion_to_uuid(payload varbit) RETURNS uuid
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _bits bit(128);
BEGIN
  IF length(payload) <> 122 THEN
    RAISE EXCEPTION 'IronLion payload is % bits, expected 122', length(payload);
  END IF;

  _bits := substring(payload FROM 1 FOR 48) || B'1000' ||
           substring(payload FROM 49 FOR 12) || B'10' ||
           substring(payload FROM 61 FOR 62);

  RETURN (
    lpad(to_hex(substring(_bits FROM 1 FOR 64)::bit(64)::bigint), 16, '0') ||
    lpad(to_hex(substring(_bits FROM 65 FOR 64)::bit(64)::bigint), 16, '0')
  )::uuid;
END
$iron_lion$;

-- The first non-null value among a row's candidate columns.
CREATE OR REPLACE FUNCTION iron_lion_row(row_data jsonb, VARIADIC columns text[]) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _column text;
BEGIN
  FOREACH _column IN ARRAY columns LOOP
    IF row_data ->> _column IS NOT NULL THEN
      RETURN row_data ->> _column;
    END IF;
  END LOOP;

  RETURN NULL;
END
$iron_lion$;

-- Like iron_lion_row, but a numeric column (bigint, h3index cast) becomes hex.
CREATE OR REPLACE FUNCTION iron_lion_row_h3(row_data jsonb, VARIADIC columns text[]) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
DECLARE
  _column text;
BEGIN
  FOREACH _column IN ARRAY columns LOOP
    IF row_data ->> _column IS NOT NULL THEN
      IF jsonb_typeof(row_data -> _column) = 'number' THEN
        RETURN to_hex((row_data ->> _column)::bigint);
      END IF;

      RETURN row_data ->> _column;
    END IF;
  END LOOP;

  RETURN NULL;
END
$iron_lion$;

-- A row's own coordinates as a geohash: latitude/longitude, lat/lng or lat/lon.
CREATE OR REPLACE FUNCTION iron_lion_row_geohash(row_data jsonb, chars integer) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $iron_lion$
BEGIN
  RETURN coalesce(
    iron_lion_geohash((row_data ->> 'latitude')::numeric, (row_data ->> 'longitude')::numeric, chars),
    iron_lion_geohash((row_data ->> 'lat')::numeric, (row_data ->> 'lng')::numeric, chars),
    iron_lion_geohash((row_data ->> 'lat')::numeric, (row_data ->> 'lon')::numeric, chars)
  );
END
$iron_lion$;
