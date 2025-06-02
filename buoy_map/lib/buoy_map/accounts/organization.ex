defmodule BuoyMap.Accounts.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  alias BuoyMap.Accounts.User
  alias BuoyMap.Maritime.Vessel # New Vessel schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field :name, :string # Company name

    has_many :users, User
    has_many :vessels, Vessel # An organization owns multiple vessels

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name, message: "An organization with this name already exists")
  end
end
