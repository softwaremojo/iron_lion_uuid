CREATE TEMP FUNCTION iron_lion_uuid() RETURNS TEXT
BEGIN
  RETURN lower(hex(randomblob(4))) || '-' ||
         lower(hex(randomblob(2))) || '-' ||
         lower(hex(randomblob(2))) || '-' ||
         lower(hex(randomblob(2))) || '-' ||
         lower(hex(randomblob(6)));
END;
