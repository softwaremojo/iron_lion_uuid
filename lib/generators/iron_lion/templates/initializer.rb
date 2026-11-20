# frozen_string_literal: true

# Your organisation's one IronLion format: what every id carries, most
# significant first. A 48-bit created_at leads and leftover bits become random,
# so neither needs declaring. Decode any id with IronLion.parse(id), or fetch
# its record with IronLion.find(id).
#
# Values come from the explicit argument, then the record (tenant_id for
# tenant), then a `from:` resolver, then ENV["IRON_LION_<FIELD>"]. In Postgres
# the row's columns play the record and `iron_lion.<field>` settings play ENV:
#   ALTER DATABASE <%= Rails.application.class.module_parent_name.underscore %>_production SET iron_lion.node = '1';
IronLion.configure do
  model    bits: 10  # 1,024 models, numbered in config/iron_lion.yml

  # tenant   bits: 20  # read from each record's tenant_id
  # node     bits: 8   # ENV["IRON_LION_NODE"] / iron_lion.node
  # region   h3: 5     # an H3 cell
  # location geohash: 6  # from each record's latitude/longitude
  # account  chars: 6  # a short alphanumeric code, e.g. a subdomain

  sequence bits: 12  # 4,096 ids per millisecond before borrowing the next one
end
