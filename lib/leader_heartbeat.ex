defmodule ExSynodse.LeaderHeartbeat do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  schema "leader_heartbeats" do
    field(:era, :string)
    field(:epoch, :integer)
    field(:node_id, :string)
    field(:valid_until, :utc_datetime)

    timestamps()
  end

  @required_fields [:era, :epoch, :node_id, :valid_until]

  def changeset(leader_heartbeat, attrs) do
    leader_heartbeat
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:era, :epoch], name: :leader_heartbeats_era_epoch_index)
  end
end
