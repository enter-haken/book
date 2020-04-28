defmodule Book.MixProject do
  use Mix.Project

  def project do
    [
      app: :book,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Book.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.8"},
      {:plug_cowboy, "~> 2.0"},
      {:earmark, "~> 1.4.3"}
    ]
  end
end
