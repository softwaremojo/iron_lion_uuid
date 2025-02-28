# frozen_string_literal: true

def iron_lion
  IronLionUUID.definition do
    timestamp bits: 48
    sequence  bits: 10
    envar     bits: 12, name: :node, key: :iron_lion_uuid_node_id
    parameter bits: 32, name: :model
    random    bits: 20
  end
end
