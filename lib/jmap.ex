defmodule Jmap do
  @moduledoc ~S"""
  Basic JMAP client for Elixir.

  This module provides a high-level interface for interacting with JMAP email servers.
  It handles all the complexity of fetching emails, downloading blobs, and sanitizing content.

  It was purpose built for fetching a single email at a time from FastMail. However, it may
  serve for others as a useful starting point for building a more feature rich client.


  ## Configuration

  In order to use JMAP, you'll need to configure a JMAP provider and token.

  ```elixir
  config :jmap,
    provider: "fastmail",
    api_token: "your_api_token"
  ```


  ## Creating a client

  Once you have a provider and token, you can create a client.

  ```elixir
  {:ok, client} = Jmap.new()
  ```

  This returns an authenticated client struct or fails if the provider or token are invalid.

  ## Getting email

  ```elixir
  {:ok, email} = Jmap.get_next_mail(client)
  #=> %Jmap.Email{
    id: "Md45jz",
    subject: "Meeting Tomorrow",
    from: [
      %Jmap.Email.EmailAddress{
        name: "John Smith",
        email: "john.smith@example.com"
      }
    ],
    to: [
      %Jmap.Email.EmailAddress{
        name: "Jane Doe",
        email: "jane.doe@example.com"
      }
    ],
    received_at: "2024-03-20T15:30:00Z",
    text_body: %Jmap.Email.EmailBody{
      blob_id: "blob_123",
      type: "text/plain",
      charset: "utf-8",
      part_id: "part1",
      size: 423,
      contents: "Hi Jane,\n\nJust confirming our meeting tomorrow at 2pm.\n\nBest regards,\nJohn"
    },
    html_body: %Jmap.Email.EmailBody{
      blob_id: "blob_124",
      type: "text/html",
      charset: "utf-8",
      part_id: "part2",
      size: 628,
      contents: "<div><p>Hi Jane,</p><p>Just confirming our meeting tomorrow at 2pm.</p><p>Best regards,<br>John</p></div>"
    },
    attachments: [
      %Jmap.Email.Attachment{
        blob_id: "blob_125",
        type: "application/pdf",
        name: "agenda.pdf",
        size: 125_840,
        disposition: "attachment",
        contents: <<...>>  # Binary content
      }
    ],
    thread_id: "thread_789"
  }
  ```

  This returns the next email from the inbox. By default, it will return the oldest email first.
  You can pass a `limit` and `offset` to paginate through the emails.

  ```elixir
  {:ok, email} = Jmap.get_next_mail(client, limit: 10, offset: 0)
  ```

  You can also change the default sort order by passing a `sort` option.

  ```elixir
  {:ok, email} = Jmap.get_next_mail(client,
    sort: [%{"isAscending" => false, "property" => "receivedAt"}])
  ```

  ## Get an email by ID.

  This works exactly like `Jmap.get_next_mail/1` but it will return an email by ID.

  ```elixir
  {:ok, email} = Jmap.get_email(client, "email_id")
  ```

  This returns an email by ID.
  """

  alias Jmap.Email
  alias Jmap.Helpers.String, as: StringHelper

  defdelegate new(), to: Jmap.Client
  defdelegate new(api_token, provider, options \\ []), to: Jmap.Client
  defdelegate fetch_emails(client, options \\ []), to: Jmap.Client
  defdelegate archive_email(client, email_id), to: Jmap.Client
  defdelegate fetch_email(client, email_id), to: Jmap.Client
  defdelegate fetch_blob(client, blob_id), to: Jmap.Client

  @doc """
  Fetches the oldest email from the inbox, including its full contents.

  This function handles all the complexity of:
  - Fetching the email metadata
  - Downloading the email body contents
  - Downloading attachment contents
  - Sanitizing HTML content
  - Inlining embedded images
  - Converting the data into a structured format

  ## Parameters
    - client: The JMAP client struct

  ## Examples
      iex> Jmap.get_next_mail(client)
      {:ok, %Jmap.Email{subject: "Hello", text_body: %{contents: "Hello world"}}}
      iex> Jmap.get_next_mail(client)
      {:error, "Inbox empty"}
  """
  def get_next_mail(client) do
    with {:ok, %{"ids" => []}} <- fetch_emails(client, limit: 1, offset: 0) do
      {:error, "Inbox empty"}
    else
      {:ok, %{"ids" => [email_id | _]}} ->
        with {:ok, email_data} <- fetch_email(client, email_id),
             email = Email.new(email_data),
             {:ok, email_with_contents} <- populate_email_contents(email, client) do
          {:ok, email_with_contents}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches an email by its ID, including its full contents.

  This function handles all the complexity of:
  - Fetching the email metadata
  - Downloading the email body contents
  - Downloading attachment contents
  - Sanitizing HTML content
  - Inlining embedded images
  - Converting the data into a structured format

  ## Parameters
    - client: The JMAP client struct
    - email_id: The ID of the email to fetch

  ## Examples
      iex> Jmap.get_email(client, "email123")
      {:ok, %Jmap.Email{subject: "Hello", text_body: %{contents: "Hello world"}}}
      iex> Jmap.get_email(client, "email123")
      {:error, "Inbox empty"}
  """
  def get_email(client, email_id) do
    with {:ok, email_data} <- fetch_email(client, email_id),
         email = Email.new(email_data),
         {:ok, email_with_contents} <- populate_email_contents(email, client) do
      {:ok, email_with_contents}
    end
  end

  defp populate_email_contents(email, client) do
    with {:ok, text_body} <- fetch_text_body(email.text_body, client),
         {:ok, html_body} <- fetch_html_body(email.html_body, client),
         {:ok, attachments} <- fetch_attachment_contents(email.attachments, client),
         {:ok, html_body_with_images} <- inline_images(html_body, attachments) do
      {:ok,
       %{email | text_body: text_body, html_body: html_body_with_images, attachments: attachments}}
    end
  end

  defp fetch_text_body(nil, _client), do: {:ok, nil}
  defp fetch_text_body(body, client), do: fetch_body_content(body, client)

  defp fetch_html_body(nil, _client), do: {:ok, nil}
  defp fetch_html_body(body, client), do: fetch_body_content(body, client)

  defp fetch_body_content(body, client) do
    case fetch_blob(client, body.blob_id) do
      {:ok, content} ->
        content =
          if body.type == "text/html" do
            StringHelper.sanitize_printable(content)
          else
            content
          end

        {:ok, %{body | contents: content}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_attachment_contents(attachments, client) do
    Enum.reduce_while(attachments, {:ok, []}, fn attachment, {:ok, acc} ->
      case fetch_attachment_content(attachment, client) do
        {:ok, attachment_with_content} -> {:cont, {:ok, [attachment_with_content | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp fetch_attachment_content(attachment, client) do
    case fetch_blob(client, attachment.blob_id) do
      {:ok, content} ->
        {:ok, %{attachment | contents: content}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp inline_images(nil, _attachments), do: {:ok, nil}

  defp inline_images(html_body, attachments) do
    inline_attachments = Enum.filter(attachments, &(&1.disposition == "inline" && &1.cid))
    content = html_body.contents

    content_with_images =
      Enum.reduce(inline_attachments, content, fn attachment, acc ->
        cid = attachment.cid
        base64 = Base.encode64(attachment.contents)
        mime_type = attachment.type
        replacement = "data:#{mime_type};base64,#{base64}"
        String.replace(acc, "cid:#{cid}", replacement)
      end)

    {:ok, %{html_body | contents: content_with_images}}
  end
end
