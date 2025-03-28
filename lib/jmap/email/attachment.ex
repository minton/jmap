defmodule Jmap.Email.Attachment do
  @moduledoc """
  Represents an email attachment from the JMAP API.
  """

  @type t :: %__MODULE__{
          blob_id: String.t(),
          charset: String.t() | nil,
          cid: String.t() | nil,
          disposition: String.t() | nil,
          language: String.t() | nil,
          location: String.t() | nil,
          name: String.t() | nil,
          part_id: String.t(),
          size: integer(),
          type: String.t(),
          contents: binary() | nil
        }

  defstruct [
    :blob_id,
    :charset,
    :cid,
    :disposition,
    :language,
    :location,
    :name,
    :part_id,
    :size,
    :type,
    :contents
  ]
end
