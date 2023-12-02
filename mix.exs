defmodule WithTimeout.MixProject do
  use Mix.Project

  @name "WithTimeout"
  @version "0.1.1"
  @description "Both total and time limited evaluation of expressions"
  @repo_url "https://github.com/iamafanasyev/with_timeout"

  def project do
    [
      app: :with_timeout,
      version: @version,
      elixir: "~> 1.2",
      deps: deps(),
      # Hex
      description: @description,
      package: package(),
      # ExDoc
      name: @name,
      source_url: @repo_url,
      docs: docs()
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:resource, "~> 1.0.0"}
    ]
  end

  defp docs() do
    [
      main: @name,
      extras: ["README.md"]
    ]
  end

  defp package() do
    [
      maintainers: ["Aleksandr Afanasev"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
