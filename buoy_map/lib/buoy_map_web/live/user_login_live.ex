defmodule BuoyMapWeb.UserLoginLive do
  use BuoyMapWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-sky-50 to-cyan-50 py-8 px-4">
      <div class="mx-auto max-w-md">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">Welcome Back</h1>
          <p class="text-lg text-gray-600 leading-relaxed">
            Sign in to access your Buoys
          </p>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-8 mb-6">
            <p class="text-sm text-gray-600 mb-3 text-center">New to Buoy?</p>
            <.link
              navigate={~p"/users/register"}
              class="inline-flex items-center justify-center w-full py-3 px-6 border-2 border-blue-600 text-blue-600 font-semibold rounded-xl hover:bg-blue-50 hover:text-blue-700 transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-blue-300"
            >
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"></path>
              </svg>
              Create New Account
            </.link>
          <.simple_form
            for={@form}
            id="login_form"
            action={~p"/users/log_in"}
            phx-update="ignore"
            class="space-y-6"
          >
            <div class="space-y-2">
              <label for={@form[:email].id} class="block text-sm font-semibold text-gray-700 mb-2">
                Email Address
              </label>
              <.input
                field={@form[:email]}
                type="email"
                required
                class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-green-500 focus:ring-4 focus:ring-green-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                placeholder="your.email@example.com"
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
                class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-green-500 focus:ring-4 focus:ring-green-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                placeholder="Enter your password"
              />
            </div>

            <div class="flex items-center justify-between">
              <label class="flex items-center">
                <.input
                  field={@form[:remember_me]}
                  type="checkbox"
                  class="w-5 h-5 text-green-600 border-2 border-gray-300 rounded focus:ring-green-500"
                />
                <span class="ml-3 text-sm font-medium text-gray-700">Keep me signed in</span>
              </label>
              <.link
                href={~p"/users/reset_password"}
                class="text-sm font-semibold text-green-600 hover:text-green-500 hover:underline transition-colors duration-200"
              >
                Forgot password?
              </.link>
            </div>

            <:actions>
              <button
                type="submit"
                phx-disable-with="Signing you in..."
                class="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-4 px-6 rounded-xl text-lg transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 focus:outline-none focus:ring-4 focus:ring-green-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                <span class="flex items-center justify-center">
                  Sign In
                  <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"></path>
                  </svg>
                </span>
              </button>
            </:actions>
          </.simple_form>
        </div>

        <div class="mt-8 text-center">
          <div class="bg-blue-50 rounded-xl p-4">
            <p class="text-sm text-blue-800 mb-2">Need help getting started?</p>
            <div class="flex flex-col sm:flex-row gap-2 justify-center">
              <.link
                href={~p"/users/confirmation_instructions"}
                class="text-sm font-medium text-blue-600 hover:text-blue-500 hover:underline"
              >
                Resend confirmation
              </.link>
              <span class="hidden sm:inline text-blue-400">|</span>
              <.link
                href="#"
                class="text-sm font-medium text-blue-600 hover:text-blue-500 hover:underline"
              >
                Contact support
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    socket =
      assign(socket,
        form: form
      )

    {:ok, socket, layout: false}
  end
end
