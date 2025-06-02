defmodule BuoyMap.Maritime do
  @moduledoc """
  The Maritime context, handling vessels and crew assignments.
  """

  import Ecto.Query, warn: false
  alias BuoyMap.Repo

  alias BuoyMap.Maritime.Vessel
  alias BuoyMap.Accounts.{User, Organization}

  # === Vessel Functions ===

  def list_vessels do
    Repo.all(Vessel)
  end

  def list_vessels_for_organization(%Organization{} = organization) do
    Repo.all(
      from v in Vessel,
      where: v.organization_id == ^organization.id,
      preload: [:organization, :crew_members]
    )
  end

  def get_vessel!(id) do
    Repo.get!(Vessel, id)
    |> Repo.preload([:organization, :crew_members])
  end

  def create_vessel(attrs \\ %{}) do
    %Vessel{}
    |> Vessel.changeset(attrs)
    |> Repo.insert()
  end

  def update_vessel(%Vessel{} = vessel, attrs) do
    vessel
    |> Vessel.changeset(attrs)
    |> Repo.update()
  end

  def delete_vessel(%Vessel{} = vessel) do
    Repo.delete(vessel)
  end

  def change_vessel(%Vessel{} = vessel, attrs \\ %{}) do
    Vessel.changeset(vessel, attrs)
  end

  # === Crew Assignment Functions ===

  @doc """
  Assigns a crew member (User) to a Vessel.
  Ensures the user has the 'crew' role.
  """
  def assign_crew_to_vessel(%Vessel{} = vessel, %User{} = user) do
    if user.role != :crew do
      {:error, :not_a_crew_member, "User must have the 'crew' role to be assigned to a vessel."}
    else
      # Ensure vessel is loaded with its crew members for proper addition
      vessel = Repo.preload(vessel, :crew_members)

      changeset =
        Ecto.Changeset.change(vessel)
        |> Ecto.Changeset.put_assoc(:crew_members, [user | vessel.crew_members])

      Repo.update(changeset)
    end
  end

  @doc """
  Removes a crew member (User) from a Vessel.
  """
  def remove_crew_from_vessel(%Vessel{} = vessel, %User{} = user_to_remove) do
    vessel = Repo.preload(vessel, :crew_members)
    updated_crew = Enum.reject(vessel.crew_members, fn user -> user.id == user_to_remove.id end)

    changeset =
      Ecto.Changeset.change(vessel)
      |> Ecto.Changeset.put_assoc(:crew_members, updated_crew)

    Repo.update(changeset)
  end

  @doc """
  Lists all vessels a specific crew member is assigned to.
  """
  def list_vessels_for_crew_member(%User{} = user) do
    # The User schema should have many_to_many :vessels properly defined
    # Preload vessels along with their organization for context
    user_with_vessels = Repo.preload(user, vessels: [:organization])
    user_with_vessels.vessels
  end
end
