defmodule Jmap.Thread do
  @moduledoc """
  Represents an thread from the JMAP API.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          emailIds: [String.t()]
        }
  defstruct [:id, :emailIds]
end
