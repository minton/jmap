defmodule Jmap.HttpClient do
  @moduledoc false

  @callback get(url :: String.t(), opts :: keyword()) ::
              {:ok, %{status: integer(), body: map()}} | {:error, term()}

  @callback post(url :: String.t(), body :: map(), opts :: keyword()) ::
              {:ok, %{status: integer(), body: map()}} | {:error, term()}
end
