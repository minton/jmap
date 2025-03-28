defmodule Jmap.HttpClient.Req do
  @moduledoc false

  @behaviour Jmap.HttpClient

  @impl true
  def get(url, opts \\ []) do
    case Req.get(url, opts) do
      {:ok, %{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def post(url, body, opts \\ []) do
    case Req.post(url, Keyword.merge([json: body], opts)) do
      {:ok, %{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
