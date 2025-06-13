defmodule Uploads.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      UploadsWeb.Telemetry,
      # Uploads.Repo,
      {DNSCluster, query: Application.get_env(:uploads, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Uploads.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Uploads.Finch},
      # Start a worker by calling: Uploads.Worker.start_link(arg)
      # {Uploads.Worker, arg},
      # Start to serve requests, typically the last entry
      UploadsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Uploads.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UploadsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
