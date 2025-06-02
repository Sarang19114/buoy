defmodule BuoyMapWeb.UserSettingsLive do
  use BuoyMapWeb, :live_view

  alias BuoyMap.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-sky-50 to-cyan-50 py-8 px-4">
      <div class="mx-auto max-w-4xl">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">Account Settings</h1>
          <p class="text-lg text-gray-600 leading-relaxed">
            Manage your account email address and password settings
          </p>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-6 sm:p-8 mb-6">
          <!-- Two-column layout for desktop, single column for mobile -->
          <div class="grid grid-cols-1 lg:grid-cols-2 lg:gap-8 space-y-8 lg:space-y-0">

            <!-- Left Column - Email Settings -->
            <div class="space-y-6">
              <div class="border-b border-gray-200 pb-4 lg:border-b-0 lg:pb-0">
                <h2 class="text-xl font-semibold text-gray-900 mb-2 flex items-center">
                  <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                  </svg>
                  Email Settings
                </h2>
                <p class="text-sm text-gray-600">Update your email address</p>
              </div>

              <.simple_form
                for={@email_form}
                id="email_form"
                phx-submit="update_email"
                phx-change="validate_email"
                class="space-y-6"
              >
                <div class="space-y-2">
                  <label for={@email_form[:email].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    New Email Address
                  </label>
                  <.input
                    field={@email_form[:email]}
                    type="email"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="your.new.email@example.com"
                  />
                </div>

                <div class="space-y-2">
                  <label for="current_password_for_email" class="block text-sm font-semibold text-gray-700 mb-2">
                    Current Password
                  </label>
                  <.input
                    field={@email_form[:current_password]}
                    name="current_password"
                    id="current_password_for_email"
                    type="password"
                    value={@email_form_current_password}
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="Enter your current password"
                  />
                </div>

                <div class="bg-blue-50 border border-blue-200 rounded-xl p-4">
                  <div class="flex">
                    <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    <div class="text-sm text-blue-800">
                      <p class="font-medium">Email Change Process</p>
                      <p class="text-xs text-blue-700 mt-1">A confirmation link will be sent to your new email address.</p>
                    </div>
                  </div>
                </div>

                <:actions>
                  <button
                    type="submit"
                    phx-disable-with="Changing..."
                    class="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-4 px-6 rounded-xl text-lg transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 focus:outline-none focus:ring-4 focus:ring-green-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                  >
                    <span class="flex items-center justify-center">
                      Change Email
                      <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                      </svg>
                    </span>
                  </button>
                </:actions>
              </.simple_form>
            </div>

            <!-- Right Column - Password Settings -->
            <div class="space-y-6">
              <div class="border-b border-gray-200 pb-4 lg:border-b-0 lg:pb-0">
                <h2 class="text-xl font-semibold text-gray-900 mb-2 flex items-center">
                  <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                  </svg>
                  Password Settings
                </h2>
                <p class="text-sm text-gray-600">Update your password</p>
              </div>

              <.simple_form
                for={@password_form}
                id="password_form"
                action={~p"/users/log_in?_action=password_updated"}
                method="post"
                phx-change="validate_password"
                phx-submit="update_password"
                phx-trigger-action={@trigger_submit}
                class="space-y-6"
              >
                <input
                  name={@password_form[:email].name}
                  type="hidden"
                  id="hidden_user_email"
                  value={@current_email}
                />

                <div class="space-y-2">
                  <label for={@password_form[:password].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    New Password
                  </label>
                  <.input
                    field={@password_form[:password]}
                    type="password"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="Create a new secure password"
                  />
                </div>

                <div class="space-y-2">
                  <label for={@password_form[:password_confirmation].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    Confirm New Password
                  </label>
                  <.input
                    field={@password_form[:password_confirmation]}
                    type="password"
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="Confirm your new password"
                  />
                </div>

                <div class="space-y-2">
                  <label for="current_password_for_password" class="block text-sm font-semibold text-gray-700 mb-2">
                    Current Password
                  </label>
                  <.input
                    field={@password_form[:current_password]}
                    name="current_password"
                    type="password"
                    id="current_password_for_password"
                    value={@current_password}
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="Enter your current password"
                  />
                </div>

                <div class="bg-blue-50 border border-blue-200 rounded-xl p-4">
                  <div class="flex">
                    <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    <div class="text-sm text-blue-800">
                      <p class="font-medium mb-1">Password requirements:</p>
                      <ul class="text-xs space-y-1 text-blue-700">
                        <li>• At least 12 characters long (recommended)</li>
                        <li>• Mix of letters, numbers & symbols</li>
                      </ul>
                    </div>
                  </div>
                </div>

                <:actions>
                  <button
                    type="submit"
                    phx-disable-with="Changing..."
                    class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 px-6 rounded-xl text-lg transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 focus:outline-none focus:ring-4 focus:ring-blue-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                  >
                    <span class="flex items-center justify-center">
                      Change Password
                      <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                      </svg>
                    </span>
                  </button>
                </:actions>
              </.simple_form>
            </div>
          </div>
        </div>

        <div class="mt-8 text-center">
          <div class="bg-blue-50 rounded-xl p-4">
            <p class="text-sm text-blue-800">
              Need help with your account settings?
              <.link
                href="#"
                class="font-medium text-blue-600 hover:text-blue-500 hover:underline ml-1"
              >
                Contact Support
              </.link>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket, layout: false}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
