defmodule BuoyMap.Repo.Migrations.CreateVesselsAndUsersVesselsJoinTable do
  use Ecto.Migration

  def change do
    create table(:vessels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :identifier, :string, null: false
      add :organization_id, references(:organizations, on_delete: :restrict, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end
    create index(:vessels, [:organization_id])
    create unique_index(:vessels, [:identifier]) # Assuming identifier is globally unique

    create table(:users_vessels, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), primary_key: true
      add :vessel_id, references(:vessels, on_delete: :delete_all, type: :binary_id), primary_key: true
    end
    # No timestamps typically needed for a join table
    # A unique index on both fields ensures a user is not assigned to the same vessel multiple times
    create unique_index(:users_vessels, [:user_id, :vessel_id])
  end
end
