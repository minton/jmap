defmodule Jmap.Email do
  @moduledoc """
  Represents an email message from the JMAP API.
  """

  alias Jmap.Email.{EmailAddress, EmailBody, Attachment}

  @typedoc """
  Represents a complete email message with all its components.

  Fields:
  - id: Unique identifier for the email
  - subject: Email subject line
  - from: List of sender email addresses
  - to: List of recipient email addresses
  - received_at: Timestamp when the email was received
  - text_body: List of plain text versions of the email body
  - html_body: List of HTML versions of the email body
  - attachments: List of files attached to the email
  - thread_id: Identifier for the conversation thread this email belongs to
  - original_quote: The quoted text from previous emails in the thread
  """
  @type t :: %__MODULE__{
          id: String.t(),
          subject: String.t(),
          from: [EmailAddress.t()],
          to: [EmailAddress.t()],
          received_at: String.t(),
          text_body: [EmailBody.t()],
          html_body: [EmailBody.t()],
          attachments: [Attachment.t()],
          thread_id: String.t(),
          original_quote: EmailBody.t() | nil
        }

  @typedoc """
  Represents an email address with an optional display name.

  Fields:
  - name: Optional display name (e.g., "John Doe")
  - email: The actual email address (e.g., "john@example.com")
  """
  @type email_address :: %EmailAddress{
          name: String.t() | nil,
          email: String.t()
        }

  @typedoc """
  Represents the body content of an email, either in text or HTML format.

  Fields:
  - blob_id: Unique identifier for the content blob
  - charset: Character encoding of the content
  - cid: Content-ID for inline attachments
  - disposition: How the content should be displayed
  - language: Content language code
  - location: URI indicating where the content can be found
  - name: Optional name for the content part
  - part_id: Identifier for this specific email part
  - size: Size of the content in bytes
  - type: MIME type of the content
  - contents: The actual content string
  """
  @type email_body :: %EmailBody{
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
          contents: String.t() | nil
        }

  @typedoc """
  Represents an email attachment.

  Fields:
  - blob_id: Unique identifier for the attachment blob
  - charset: Character encoding if applicable
  - cid: Content-ID for inline attachments
  - disposition: How the attachment should be handled
  - language: Content language code
  - location: URI indicating where the attachment can be found
  - name: Filename of the attachment
  - part_id: Identifier for this specific email part
  - size: Size of the attachment in bytes
  - type: MIME type of the attachment
  - contents: The binary content of the attachment
  """
  @type attachment :: %Attachment{
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
    :id,
    :subject,
    :from,
    :to,
    :received_at,
    :text_body,
    :html_body,
    :attachments,
    :thread_id,
    :original_quote
  ]

  @doc """
  Creates a new Email struct from raw JMAP data.

  ## Parameters
    - `data`: Map containing the raw email data from JMAP

  ## Examples
      iex> data = %{
      ...>   "id" => "email123",
      ...>   "subject" => "Hello",
      ...>   "from" => [%{"email" => "sender@example.com", "name" => "Sender"}],
      ...>   "to" => [%{"email" => "recipient@example.com", "name" => "Recipient"}],
      ...>   "receivedAt" => "2024-01-01T00:00:00Z",
      ...>   "textBody" => [
      ...>     %{"blobId" => "blob123", "type" => "text/plain"},
      ...>     %{"blobId" => "blob124", "type" => "text/plain"}
      ...>   ],
      ...>   "threadId" => "thread123"
      ...> }
      iex> Email.new(data)
      %Email{
        id: "email123",
        subject: "Hello",
        from: [%EmailAddress{email: "sender@example.com", name: "Sender"}],
        to: [%EmailAddress{email: "recipient@example.com", name: "Recipient"}],
        received_at: "2024-01-01T00:00:00Z",
        text_body: [
          %EmailBody{blob_id: "blob123", type: "text/plain"},
          %EmailBody{blob_id: "blob124", type: "text/plain"}
        ],
        html_body: [],
        attachments: [],
        thread_id: "thread123",
        original_quote: nil
      }
  """
  def new(data) do
    text_parts = process_body_parts(data["textBody"])
    html_parts = process_body_parts(data["htmlBody"])

    %__MODULE__{
      id: data["id"],
      subject: data["subject"],
      from: Enum.map(data["from"] || [], &new_email_address/1),
      to: Enum.map(data["to"] || [], &new_email_address/1),
      received_at: data["receivedAt"],
      text_body: text_parts.main_parts,
      html_body: html_parts.main_parts,
      attachments: Enum.map(data["attachments"] || [], &new_attachment/1),
      thread_id: data["threadId"],
      original_quote: html_parts.original_quote
    }
  end

  defp process_body_parts(nil), do: %{main_parts: [], original_quote: nil}
  defp process_body_parts([]), do: %{main_parts: [], original_quote: nil}

  defp process_body_parts(parts) when is_list(parts) do
    text_parts = Enum.filter(parts, &(&1["type"] == "text/plain"))

    original_quote = if length(text_parts) > 1, do: List.last(text_parts), else: nil

    # Convert all parts to EmailBody structs
    all_parts = Enum.map(parts, &new_email_body/1)

    %{
      main_parts: all_parts,
      original_quote: if(original_quote, do: new_email_body(original_quote), else: nil)
    }
  end

  defp process_body_parts(part) when is_map(part) do
    process_body_parts([part])
  end

  defp new_email_address(data) when is_map(data) do
    %EmailAddress{
      name: data["name"],
      email: data["email"]
    }
  end

  defp new_email_body(data) when is_map(data) do
    %EmailBody{
      blob_id: data["blobId"],
      charset: data["charset"],
      cid: data["cid"],
      disposition: data["disposition"],
      language: data["language"],
      location: data["location"],
      name: data["name"],
      part_id: data["partId"],
      size: data["size"],
      type: data["type"]
    }
  end

  defp new_attachment(data) when is_map(data) do
    %Attachment{
      blob_id: data["blobId"],
      charset: data["charset"],
      cid: data["cid"],
      disposition: data["disposition"],
      language: data["language"],
      location: data["location"],
      name: data["name"],
      part_id: data["partId"],
      size: data["size"],
      type: data["type"]
    }
  end

  @doc """
  Checks if two emails are part of the same thread.

  ## Parameters
    - `email1`: First Email struct
    - `email2`: Second Email struct

  ## Examples
      iex> email1 = %Email{thread_id: "thread123"}
      iex> email2 = %Email{thread_id: "thread123"}
      iex> Email.same_thread?(email1, email2)
      true

      iex> email1 = %Email{thread_id: "thread123"}
      iex> email2 = %Email{thread_id: "thread456"}
      iex> Email.same_thread?(email1, email2)
      false
  """
  def same_thread?(%__MODULE__{thread_id: thread_id1}, %__MODULE__{thread_id: thread_id2}) do
    thread_id1 == thread_id2
  end
end
