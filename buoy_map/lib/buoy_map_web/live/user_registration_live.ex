defmodule BuoyMapWeb.UserRegistrationLive do
  use BuoyMapWeb, :live_view

  alias BuoyMap.Accounts
  alias BuoyMap.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-sky-50 to-cyan-50 py-8 px-4">
      <div class="mx-auto max-w-4xl">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">Join Buoy</h1>
          <p class="text-lg text-gray-600 leading-relaxed">
            Create your account to start exploring
          </p>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-6 sm:p-8 mb-6">
            <p class="text-sm text-gray-600 mb-3 text-center">Already have an account?</p>
            <.link
              navigate={~p"/users/log_in"}
              class="inline-flex items-center justify-center w-full py-3 px-6 border-2 border-green-600 text-green-600 font-semibold rounded-xl hover:bg-green-50 hover:text-green-700 transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-green-300"
            >
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"></path>
              </svg>
              Sign In Instead
            </.link>
          <.simple_form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log_in?_action=registered"}
            method="post"
            class="space-y-6"
          >
            <.error :if={@check_errors} class="bg-red-50 border-l-4 border-red-400 text-red-700 p-4 rounded-md mb-6" role="alert">
              <p class="font-bold">Oops, something went wrong!</p>
              <p>Please check the errors below and try again.</p>
            </.error>

            <!-- Two-column layout for desktop, single column for mobile -->
            <div class="grid grid-cols-1 lg:grid-cols-2 lg:gap-8 space-y-6 lg:space-y-0">
              <!-- Left Column -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <label for={@form[:first_name].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    First Name
                  </label>
                  <.input
                    field={@form[:first_name]}
                    type="text"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="e.g., John"
                  />
                </div>

                <div class="space-y-2">
                  <label for={@form[:last_name].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    Last Name
                  </label>
                  <.input
                    field={@form[:last_name]}
                    type="text"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="e.g., Doe"
                  />
                </div>

                <div class="space-y-2">
                  <label for={@form[:nickname].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    Nickname <span class="text-gray-500 font-normal">(Optional)</span>
                  </label>
                  <.input
                    field={@form[:nickname]}
                    type="text"
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="e.g., Johnny"
                  />
                </div>

                <div class="space-y-2">
                  <label for={@form[:email].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    Email Address
                  </label>
                  <.input
                    field={@form[:email]}
                    type="email"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="your.email@example.com"
                  />
                </div>
              </div>

              <!-- Right Column -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <label for={@form[:company_name].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    Company Name
                  </label>
                  <.input
                    field={@form[:company_name]}
                    type="text"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="e.g., Oceanic Explorers Inc."
                  />
                </div>

                <div class="space-y-2">
                  <label for={@form[:phone].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    Phone Number
                  </label>
                  <.input
                    field={@form[:phone]}
                    type="tel"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="e.g., +1 555-123-4567"
                  />
                </div>

                <div class="space-y-2">
                  <label for={@form[:password].id} class="block text-sm font-semibold text-gray-700 mb-2">
                    Password
                  </label>
                  <.input
                    field={@form[:password]}
                    type="password"
                    required
                    class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-4 focus:ring-blue-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                    placeholder="Create a secure password"
                  />
                </div>

                <div class="space-y-4">
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

                  <div class="flex items-center space-x-3 pt-2">
                    <.input
                      field={@form[:fisherman_status]}
                      type="checkbox"
                      class="h-5 w-5 text-blue-600 border-2 border-gray-300 rounded focus:ring-blue-500"
                    />
                    <label for={@form[:fisherman_status].id} class="text-sm font-medium text-gray-700 select-none">
                      Are you a fisherman?
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <:actions>
              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 px-6 rounded-xl text-lg transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 focus:outline-none focus:ring-4 focus:ring-blue-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                <span class="flex items-center justify-center">
                  Create Account
                  <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"></path>
                  </svg>
                </span>
              </button>
            </:actions>
          </.simple_form>

        </div>

        <div class="mt-8 text-center">
          <div class="bg-blue-50 rounded-xl p-4">
            <p class="text-sm text-blue-800 mb-2">By creating an account, you agree to our</p>
            <div class="flex flex-col sm:flex-row gap-2 justify-center">
              <.link
                href="#"
                class="text-sm font-medium text-blue-600 hover:text-blue-500 hover:underline"
              >
                Terms of Service
              </.link>
              <span class="hidden sm:inline text-blue-400">&</span>
              <.link
                href="#"
                class="text-sm font-medium text-blue-600 hover:text-blue-500 hover:underline"
              >
                Privacy Policy
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    # IMPORTANT: Ensure your User schema and Accounts.change_user_registration/1
    # function are updated to include all these new fields:
    # :first_name, :last_name, :nickname, :company_name, :phone, :fisherman_status
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, layout: false, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    # IMPORTANT: Ensure Accounts.register_user/1 can handle all new user_params
    # and that your User schema + changeset correctly validate/cast them.
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    # IMPORTANT: Ensure Accounts.change_user_registration/2 can handle all new user_params for validation
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
