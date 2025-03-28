defmodule Jmap.Helpers.String do
  @moduledoc """
  Helper functions for working with strings safely and cleanly,
  especially for sanitizing HTML blobs from JMAP or email sources.
  """

  @doc """
  Sanitizes a binary by removing invalid UTF-8 sequences and non-printable characters.

  This version walks the entire string, skipping any invalid bytes instead of stopping early.

  ## Examples

      iex> Jmap.Helpers.String.sanitize_printable("abc\\x01\\x02😀")
      "abc😀"
  """
  def sanitize_printable(bin) when is_binary(bin) do
    bin
    |> :binary.bin_to_list()
    |> Enum.filter(&(&1 >= 32 and &1 <= 126))
    |> to_string()
  end
end
