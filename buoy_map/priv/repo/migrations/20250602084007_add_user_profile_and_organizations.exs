defmodule BuoyMap.Repo.Migrations.AddUserProfileAndOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end
    create unique_index(:organizations, [:name])

    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :phone, :string
      add :fisherman_status, :boolean, default: false, null: false
      add :nickname, :string
      add :role, :string, null: false # Stores the Ecto.Enum as string
      add :organization_id, references(:organizations, on_delete: :nilify_all, type: :binary_id) # Or :restrict
    end
    create index(:users, [:organization_id])
    create index(:users, [:role])
  end
end
