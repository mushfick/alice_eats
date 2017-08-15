defmodule Alice.Eats.Mixfile do
  use Mix.Project

  def project do
    [
      app: :alice_eats,
      version: "0.1.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
      description: "A handler for the Alice Slack bot. Suggest where to eat from self-curated lists of restaurants."
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:alice, "~> 0.3.6"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      files: ["lib", "config", "mix.exs", "README*"],
      maintainers: ["Adam Zaninovich", "Joe Perry"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/alice-bot/alice_eats"}
    ]
  end
end
