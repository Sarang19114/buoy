defmodule BuoyMapWeb.UserConfirmationInstructionsLive do
  use BuoyMapWeb, :live_view

  alias BuoyMap.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-sky-50 to-cyan-50 py-8 px-4">
      <div class="mx-auto max-w-md">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">Resend Confirmation</h1>
          <p class="text-lg text-gray-600 leading-relaxed">
            We'll send a new confirmation link to your inbox
          </p>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-6 sm:p-8 mb-6">
          <div class="text-center mb-6">
            <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-6">
              <div class="flex items-start">
                <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <div class="text-sm text-blue-800">
                  <p class="font-medium">No confirmation instructions received?</p>
                  <p class="text-xs text-blue-700 mt-1">
                    Enter your email address below and we'll send you a new confirmation link.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
            <div class="mb-6">
              <label for={@form[:email].name} class="block text-sm font-medium text-gray-700 mb-2">
                Email Address
              </label>
              <.input
                field={@form[:email]}
                type="email"
                placeholder="Enter your email address"
                required
                class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg"
              />
            </div>
            <:actions>
              <button
                type="submit"
                phx-disable-with="Sending..."
                class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 px-6 rounded-xl text-lg transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 focus:outline-none focus:ring-4 focus:ring-blue-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                <span class="flex items-center justify-center">
                  Resend Confirmation Instructions
                  <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
                  </svg>
                </span>
              </button>
            </:actions>
          </.simple_form>

          <div class="mt-6 text-center">
            <p class="text-sm text-gray-500">
              By requesting new instructions, you agree to our
              <.link href="#" class="text-blue-600 hover:text-blue-500 hover:underline font-medium">
                Terms of Service
              </.link>
              and
              <.link href="#" class="text-blue-600 hover:text-blue-500 hover:underline font-medium">
                Privacy Policy
              </.link>
            </p>
          </div>
        </div>

        <div class="text-center">
          <div class="bg-white rounded-xl p-4 shadow-md">
            <p class="text-sm text-gray-600 mb-3">Already have your confirmation link?</p>
            <div class="flex flex-col sm:flex-row gap-3 justify-center">
              <.link
                navigate={~p"/users/log_in"}
                class="inline-flex items-center justify-center px-6 py-3 border-2 border-blue-600 text-blue-600 font-semibold rounded-xl hover:bg-blue-50 hover:text-blue-700 transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-blue-300"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"></path>
                </svg>
                Sign In
              </.link>
              <.link
                navigate={~p"/users/register"}
                class="inline-flex items-center justify-center px-6 py-3 border-2 border-green-600 text-green-600 font-semibold rounded-xl hover:bg-green-50 hover:text-green-700 transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-green-300"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"></path>
                </svg>
                Create New Account
              </.link>
            </div>
          </div>
        </div>

        <div class="mt-6 text-center">
          <div class="bg-amber-50 border border-amber-200 rounded-xl p-4">
            <div class="flex items-start">
              <svg class="w-5 h-5 text-amber-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <div class="text-sm text-amber-800">
                <p class="font-medium">Still Having Issues?</p>
                <p class="text-xs text-amber-700 mt-1">
                  If you continue to have problems receiving confirmation emails, please check your spam folder or contact support.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
