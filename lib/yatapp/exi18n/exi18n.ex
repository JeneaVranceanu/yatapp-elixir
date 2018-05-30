defmodule Yatapp.ExI18n do
  @moduledoc """
  ExI18n - key-based internationalization library.
  """
  alias Yatapp.Env

  @table :exi18n_translations

  @doc "Default locale set in configuration."
  def locale, do: Env.get(:default_locale) || "en"

  @doc "Supported locales."
  def locales, do: Env.get(:locales) || ~w(en)

  @doc "Flag to determine if fallback to default locale."
  def fallback, do: Env.get(:fallback) || false

  @doc """
  Search for translation in given `locale` based on provided `key`.
  ## Parameters
    - `locale`: `String` with name of locale.
    - `key`: `String` with path to translation.
    - `values`: `Map` with values that will be interpolated.
  ## Examples
      iex> Yatapp.ExI18n.t("en", "hello")
      "Hello world"
      iex> Yatapp.ExI18n.t("en", "hello_name", name: "Joe")
      "Hello Joe"
      iex> Yatapp.ExI18n.t("en", "invalid")
      ** (ArgumentError) Missing translation for key: invalid
      iex> Yatapp.ExI18n.t("en", "incomplete.path")
      ** (ArgumentError) incomplete.path is incomplete path to translation.
      iex> Yatapp.ExI18n.t("en", "hello_name", name: %{"1" => "2"})
      ** (ArgumentError) Only string, boolean or number allowed for values.
  """
  @spec t(String.t(), String.t(), Map.t()) :: String.t()
  def t(locale, key), do: t(locale, key, %{})

  def t(_, key, _) when not is_bitstring(key) do
    raise ArgumentError, "Invalid key - must be string"
  end

  def t(locale, key, values) when not is_map(values) do
    t(locale, key, convert_values(values))
  end

  def t(locale, key, values) do
    locale
    |> check_locale
    |> get_translation(key)
    |> check_translation(key)
    |> check_values(values)
    |> compile(key, values)
  end

  defp convert_values(values) do
    try do
      Enum.into(values, %{})
    rescue
      _ -> raise ArgumentError, "Values for translation need to be a map or keyword list"
    end
  end

  defp check_locale(locale) do
    if locale in locales(), do: locale, else: locale()
  end

  defp get_translation(locale, key) do
    locale_key = Enum.join([locale, key], ".")

    case :ets.lookup(@table, locale_key) do
      [{^locale_key, translation}] -> translation
      [] -> []
    end
  end

  defp check_translation("", key) do
    if fallback(), do: get_translation(locale(), key), else: ""
  end

  defp check_translation(translation, _), do: translation

  defp check_values(translation, values) do
    values
    |> Map.values()
    |> Enum.all?(&validate_value/1)
    |> validate_values(translation)
  end

  defp validate_value(value) do
    is_bitstring(value) or is_number(value) or is_boolean(value)
  end

  defp validate_values(true, translation), do: translation

  defp validate_values(false, _) do
    raise ArgumentError, "Only string, boolean or number allowed for values."
  end

  defp compile(text, _, _) when is_number(text), do: text

  defp compile(text, _, values) when is_bitstring(text) or is_list(text) do
    Yatapp.ExI18n.Compiler.compile(text, values)
  end

  defp compile(nil, key, _) do
    raise ArgumentError, "Missing translation for key: #{key}"
  end

  defp compile(_, key, _) do
    raise ArgumentError, "#{key} is incomplete path to translation."
  end
end
