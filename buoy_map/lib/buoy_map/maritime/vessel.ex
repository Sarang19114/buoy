defmodule BuoyMap.Maritime.Vessel do
  use Ecto.Schema
  import Ecto.Changeset

  alias BuoyMap.Accounts.Organization
  alias BuoyMap.Accounts.User
  # If you have a Buoy schema, you might link it here too:
  # alias BuoyMap.Buoys.Buoy

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "vessels" do
    field :name, :string
    field :identifier, :string # Unique identifier for the vessel

    belongs_to :organization, Organization
    many_to_many :crew_members, User, join_through: "users_vessels", on_replace: :delete
    # has_many :buoys, Buoy # Example: If a vessel has many buoys

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(vessel, attrs) do
    vessel
    |> cast(attrs, [:name, :identifier, :organization_id])
    |> validate_required([:name, :identifier, :organization_id])
    |> unique_constraint(:identifier, name: :vessels_identifier_index, message: "A vessel with this identifier already exists")
    |> assoc_constraint(:organization)
  end
end
