defmodule Jmap.Email.EmailAddress do
  @moduledoc """
  Represents an email address with an optional display name.
  """
  defstruct [:name, :email]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          email: String.t()
        }
end
