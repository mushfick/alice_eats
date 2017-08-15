defmodule Alice.Eats.Mixfile do
  use Mix.Project

  def project do
    [
      app: :alice_eats,
      version: "0.1.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:alice, "~> 0.3.6"}
    ]
  end
end
