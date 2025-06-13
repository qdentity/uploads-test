defmodule Uploads.Repo do
  use Ecto.Repo,
    otp_app: :uploads,
    adapter: Ecto.Adapters.Postgres
end
