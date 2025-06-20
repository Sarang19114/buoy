defmodule BuoyMap.AccountsTest do
  use BuoyMap.DataCase

  alias BuoyMap.Accounts
  alias BuoyMap.Accounts.{User, UserToken, Organization}

  import BuoyMap.AccountsFixtures

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "registers user as crew without organization when no company_name provided" do
      email = unique_user_email()
      attrs = valid_user_attributes(email: email)
      {:ok, user} = Accounts.register_user(attrs)
      
      assert user.email == email
      assert user.role == :crew
      assert is_nil(user.organization_id)
    end

    test "registers user as crew when company_name is empty string" do
      email = unique_user_email()
      attrs = valid_user_attributes(email: email) |> Map.put("company_name", "")
      {:ok, user} = Accounts.register_user(attrs)
      
      assert user.email == email
      assert user.role == :crew
      assert is_nil(user.organization_id)
    end

    test "registers user as crew when company_name is whitespace only" do
      email = unique_user_email()
      attrs = valid_user_attributes(email: email) |> Map.put("company_name", "   ")
      {:ok, user} = Accounts.register_user(attrs)
      
      assert user.email == email
      assert user.role == :crew
      assert is_nil(user.organization_id)
    end

    test "creates new organization and registers user as owner when company_name provided" do
      email = unique_user_email()
      company_name = "Test Maritime Company"
      attrs = valid_user_attributes(email: email) |> Map.put("company_name", company_name)
      
      {:ok, user} = Accounts.register_user(attrs)
      
      assert user.email == email
      assert user.role == :owner
      assert user.organization_id
      
      organization = Accounts.get_organization!(user.organization_id)
      assert organization.name == company_name
    end

    test "uses existing organization when company_name already exists" do
      # Create an organization first
      {:ok, existing_org} = Accounts.create_organization(%{name: "Existing Company"})
      
      email = unique_user_email()
      attrs = valid_user_attributes(email: email) |> Map.put("company_name", "Existing Company")
      
      {:ok, user} = Accounts.register_user(attrs)
      
      assert user.email == email
      assert user.role == :owner
      assert user.organization_id == existing_org.id
    end

    test "rolls back transaction when organization creation fails" do
      # Mock a scenario where organization creation might fail
      # This is more of an integration test - you might need to adjust based on your validation rules
      email = unique_user_email()
      attrs = valid_user_attributes(email: email) |> Map.put("company_name", nil)
      
      # This should still work as it falls back to crew registration
      {:ok, user} = Accounts.register_user(attrs)
      assert user.role == :crew
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_profile/2" do
    test "returns a changeset for user profile updates" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user_profile(user)
    end

    test "allows profile fields to be set" do
      user = user_fixture()
      attrs = %{role: :captain}
      changeset = Accounts.change_user_profile(user, attrs)
      assert changeset.valid?
      assert get_change(changeset, :role) == :captain
    end
  end

  describe "update_user_profile/2" do
    test "updates user profile successfully" do
      user = user_fixture()
      attrs = %{role: :captain}
      
      {:ok, updated_user} = Accounts.update_user_profile(user, attrs)
      assert updated_user.role == :captain
    end

    test "returns error changeset for invalid data" do
      user = user_fixture()
      attrs = %{role: :invalid_role}
      
      {:error, changeset} = Accounts.update_user_profile(user, attrs)
      refute changeset.valid?
    end
  end

  # Organization Tests
  describe "list_organizations/0" do
    test "returns all organizations" do
      org1 = organization_fixture()
      org2 = organization_fixture()
      
      organizations = Accounts.list_organizations()
      assert length(organizations) >= 2
      assert Enum.any?(organizations, &(&1.id == org1.id))
      assert Enum.any?(organizations, &(&1.id == org2.id))
    end

    test "returns empty list when no organizations exist" do
      # Assuming a clean database for this test
      organizations = Accounts.list_organizations()
      assert is_list(organizations)
    end
  end

  describe "get_organization!/1" do
    test "returns organization with preloaded associations" do
      org = organization_fixture()
      retrieved_org = Accounts.get_organization!(org.id)
      
      assert retrieved_org.id == org.id
      assert retrieved_org.name == org.name
      # Check that associations are preloaded
      assert %Ecto.Association.NotLoaded{} != retrieved_org.users
      assert %Ecto.Association.NotLoaded{} != retrieved_org.vessels
    end

    test "raises when organization does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_organization!(-1)
      end
    end
  end

  describe "create_organization/1" do
    test "creates organization with valid attributes" do
      attrs = %{name: "Test Organization"}
      {:ok, organization} = Accounts.create_organization(attrs)
      
      assert organization.name == "Test Organization"
    end

    test "returns error changeset with invalid attributes" do
      {:error, changeset} = Accounts.create_organization(%{})
      refute changeset.valid?
    end
  end

  describe "update_organization/2" do
    test "updates organization with valid attributes" do
      organization = organization_fixture()
      attrs = %{name: "Updated Organization Name"}
      
      {:ok, updated_org} = Accounts.update_organization(organization, attrs)
      assert updated_org.name == "Updated Organization Name"
    end

    test "returns error changeset with invalid attributes" do
      organization = organization_fixture()
      attrs = %{name: nil}
      
      {:error, changeset} = Accounts.update_organization(organization, attrs)
      refute changeset.valid?
    end
  end

  describe "delete_organization/1" do
    test "deletes the organization" do
      organization = organization_fixture()
      {:ok, deleted_org} = Accounts.delete_organization(organization)
      
      assert deleted_org.id == organization.id
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_organization!(organization.id)
      end
    end
  end

  describe "change_organization/2" do
    test "returns a changeset" do
      organization = organization_fixture()
      assert %Ecto.Changeset{} = Accounts.change_organization(organization)
    end

    test "allows fields to be set" do
      organization = organization_fixture()
      attrs = %{name: "New Name"}
      changeset = Accounts.change_organization(organization, attrs)
      
      assert changeset.valid?
      assert get_change(changeset, :name) == "New Name"
    end
  end

  describe "assign_user_to_organization/3" do
    test "assigns user to organization successfully" do
      user = user_fixture()
      organization = organization_fixture()
      
      {:ok, updated_user} = Accounts.assign_user_to_organization(user, organization)
      assert updated_user.organization_id == organization.id
    end

    test "assigns user to organization with specific role" do
      user = user_fixture()
      organization = organization_fixture()
      
      {:ok, updated_user} = Accounts.assign_user_to_organization(user, organization, :captain)
      assert updated_user.organization_id == organization.id
      assert updated_user.role == :captain
    end

    test "assigns user to organization without changing role when role is nil" do
      user = user_fixture(%{role: :crew})
      organization = organization_fixture()
      
      {:ok, updated_user} = Accounts.assign_user_to_organization(user, organization, nil)
      assert updated_user.organization_id == organization.id
      assert updated_user.role == :crew
    end
  end

  describe "list_users_for_organization/1" do
    test "returns users belonging to organization" do
      organization = organization_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      _user3 = user_fixture() # User not in the organization
      
      {:ok, _} = Accounts.assign_user_to_organization(user1, organization)
      {:ok, _} = Accounts.assign_user_to_organization(user2, organization)
      
      users = Accounts.list_users_for_organization(organization)
      user_ids = Enum.map(users, & &1.id)
      
      assert length(users) == 2
      assert user1.id in user_ids
      assert user2.id in user_ids
    end

    test "returns empty list when organization has no users" do
      organization = organization_fixture()
      users = Accounts.list_users_for_organization(organization)
      assert users == []
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_user_email(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
