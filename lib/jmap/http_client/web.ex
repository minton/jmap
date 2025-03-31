defmodule Jmap.HttpClient.Web do
  @moduledoc false

  @behaviour Jmap.HttpClient

  @impl true
  def get(url, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    # Convert headers to charlists as required by :httpc
    headers_charlist = Enum.map(headers, fn {k, v} -> {to_charlist(k), to_charlist(v)} end)

    # Convert URL to charlist as required by :httpc
    url_charlist = to_charlist(url)

    case :httpc.request(:get, {url_charlist, headers_charlist}, [], body_format: :binary) do
      {:ok, {{_, status, _}, _resp_headers, body}} ->
        case Jason.decode(body) do
          {:ok, decoded_body} -> {:ok, %{status: status, body: decoded_body}}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def post(url, body, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    # Convert headers to charlists as required by :httpc
    headers_charlist = Enum.map(headers, fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
    content_type = ~c"application/json"

    # Ensure body is JSON encoded
    body_json = Jason.encode!(body)
    url_charlist = to_charlist(url)

    case :httpc.request(:post, {url_charlist, headers_charlist, content_type, body_json}, [],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _resp_headers, body}} ->
        case Jason.decode(body) do
          {:ok, decoded_body} -> {:ok, %{status: status, body: decoded_body}}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
