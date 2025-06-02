defmodule BuoyMapWeb.UserForgotPasswordLive do
  use BuoyMapWeb, :live_view

  alias BuoyMap.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-sky-50 to-cyan-50 py-8 px-4">
      <div class="mx-auto max-w-md">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">Forgot Password?</h1>
          <p class="text-lg text-gray-600 leading-relaxed">
            No worries! We'll send a password reset link to your inbox
          </p>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-8 mb-6">
          <.simple_form
            for={@form}
            id="reset_password_form"
            phx-submit="send_email"
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
                class="w-full px-4 py-4 text-lg border-2 border-gray-200 rounded-xl focus:border-orange-500 focus:ring-4 focus:ring-orange-100 transition-all duration-200 bg-gray-50 focus:bg-white"
                placeholder="your.email@example.com"
              />
            </div>

            <div class="bg-orange-50 border border-orange-200 rounded-xl p-4">
              <div class="flex">
                <svg class="w-5 h-5 text-orange-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <div class="text-sm text-orange-800">
                  <p class="font-medium">We'll email you a secure link to reset your password</p>
                </div>
              </div>
            </div>

            <:actions>
              <button
                type="submit"
                phx-disable-with="Sending..."
                class="w-full bg-orange-600 hover:bg-orange-700 text-white font-bold py-4 px-6 rounded-xl text-lg transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 focus:outline-none focus:ring-4 focus:ring-orange-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                <span class="flex items-center justify-center">
                  Send Reset Instructions
                  <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                  </svg>
                </span>
              </button>
            </:actions>
          </.simple_form>

          <div class="mt-6 pt-6 border-t border-gray-200">
            <div class="flex flex-col sm:flex-row gap-3">
              <.link
                navigate={~p"/users/log_in"}
                class="flex-1 inline-flex items-center justify-center py-3 px-6 border-2 border-green-600 text-green-600 font-semibold rounded-xl hover:bg-green-50 hover:text-green-700 transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-green-300"
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"></path>
                </svg>
                Sign In
              </.link>

              <.link
                navigate={~p"/users/register"}
                class="flex-1 inline-flex items-center justify-center py-3 px-6 border-2 border-blue-600 text-blue-600 font-semibold rounded-xl hover:bg-blue-50 hover:text-blue-700 transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-blue-300"
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"></path>
                </svg>
                Register
              </.link>
            </div>
          </div>
        </div>

        <div class="mt-8 text-center">
          <div class="bg-blue-50 rounded-xl p-4">
            <p class="text-sm text-blue-800 mb-2">Having trouble?</p>
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
    {:ok, assign(socket, form: to_form(%{}, as: "user")), layout: false}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
