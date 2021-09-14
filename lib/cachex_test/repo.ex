defmodule CachexTest.Repo do
  use Ecto.Repo,
    otp_app: :cachex_test,
    adapter: Ecto.Adapters.Postgres
end
