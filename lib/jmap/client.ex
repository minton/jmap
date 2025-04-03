defmodule Jmap.Client do
  @moduledoc """
  JMAP client implementation that handles the core protocol communication.
  """

  defstruct [
    :api_token,
    :provider,
    :api_url,
    :session_url,
    :account_id,
    :inbox_id,
    :archive_id,
    :download_url
  ]

  @fastmail_api_url "https://api.fastmail.com/jmap/session"

  @doc """
  Creates a new JMAP client using configuration values.

  ## Returns
    * `{:ok, client}` - on success
    * `{:error, reason}` - on failure

  ## Examples
      iex> Jmap.new()
      {:ok, %Jmap.Client{}}
  """
  def new do
    case {Application.get_env(:jmap, :api_token), Application.get_env(:jmap, :provider)} do
      {nil, _} -> {:error, "API token not configured"}
      {_, nil} -> {:error, "Provider not configured"}
      {api_token, provider} -> new(api_token, provider)
    end
  end

  @doc """
  Creates a new JMAP client with the given configuration.

  ## Parameters
    - api_token: The JMAP API token (for Fastmail, generate this in Settings -> Password & Security -> App Passwords)
    - provider: The JMAP provider (e.g., :fastmail)
    - options: Additional options (optional)
      - api_url: Custom API URL (defaults to provider's default)
      - timeout: Request timeout in milliseconds (default: 30_000)

  ## Returns
    * `{:ok, client}` - on success
    * `{:error, reason}` - on failure

  ## Examples
      iex> Jmap.new("your-api-token", :fastmail)
      {:ok, %Jmap.Client{}}
  """
  def new(api_token, provider, options \\ [])

  def new(api_token, provider, options) when is_atom(provider) do
    api_url =
      case provider do
        :fastmail ->
          Keyword.get(options, :api_url, @fastmail_api_url)

        _ ->
          Keyword.get(options, :api_url) ||
            {:error, "API URL must be provided for provider: #{inspect(provider)}"}
      end

    case api_url do
      {:error, reason} ->
        {:error, reason}

      url ->
        client = %__MODULE__{
          api_token: api_token,
          provider: provider,
          api_url: url
        }

        case authenticate(client) do
          {:ok, authenticated_client} -> {:ok, authenticated_client}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def new(_api_token, provider, _options) do
    {:error, "Invalid provider: #{inspect(provider)}. Expected an atom."}
  end

  @doc """
  Fetches emails from the Inbox.

  ## Options
    - limit: Maximum number of emails to fetch (default: 50)
    - offset: Number of emails to skip (default: 0)
    - sort: Custom sort order (default: [%{"isAscending" => true, "property" => "receivedAt"}])

  ## Returns
    * `{:ok, result}` - on success, where result contains:
      - "ids": List of email IDs
      - "total": Total number of emails
      - "position": Current position in the result set
    * `{:error, reason}` - on failure
  """
  def fetch_emails(client, options \\ []) do
    limit = Keyword.get(options, :limit, 50)
    offset = Keyword.get(options, :offset, 0)
    sort = Keyword.get(options, :sort, [%{"isAscending" => true, "property" => "receivedAt"}])

    request = %{
      "using" => ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
      "methodCalls" => [
        [
          "Email/query",
          %{
            "accountId" => client.account_id,
            "filter" => %{
              "inMailbox" => client.inbox_id
            },
            "sort" => sort,
            "position" => offset,
            "limit" => limit
          },
          "a"
        ]
      ]
    }

    case make_request(client, request) do
      {:ok, %{"accountId" => _account_id} = result} ->
        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        {:error, "Request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Archives the specified email by moving it to the Archive folder.
  """
  def archive_email(client, email_id) do
    request = %{
      "using" => ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
      "methodCalls" => [
        [
          "Email/set",
          %{
            "accountId" => client.account_id,
            "update" => %{
              email_id => %{
                "mailboxIds" => %{
                  client.archive_id => true
                }
              }
            }
          },
          "a"
        ]
      ]
    }

    case make_request(client, request) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches the full content of a specific email.

  ## Parameters
    - client: The JMAP client struct
    - email_id: The ID of the email to fetch

  ## Returns
    * `{:ok, email}` - on success, where email contains:
      - id: The email ID
      - subject: The email subject
      - from: List of sender email addresses
      - to: List of recipient email addresses
      - receivedAt: Timestamp when the email was received
      - textBody: List of text/plain body parts
      - htmlBody: List of text/html body parts
      - attachments: List of attachments
      - threadId: The thread ID this email belongs to
    * `{:error, reason}` - on failure

  ## Examples
      iex> Jmap.Client.fetch_email(client, "email123")
      {:ok, %{
        "id" => "email123",
        "subject" => "Hello",
        "from" => [%{"email" => "sender@example.com", "name" => "Sender"}],
        "to" => [%{"email" => "recipient@example.com", "name" => "Recipient"}],
        "receivedAt" => "2024-01-01T00:00:00Z",
        "textBody" => [
          %{"blobId" => "blob123", "type" => "text/plain"},
          %{"blobId" => "blob124", "type" => "text/plain"}
        ],
        "htmlBody" => [
          %{"blobId" => "blob125", "type" => "text/html"}
        ],
        "attachments" => [],
        "threadId" => "thread123"
      }}
  """
  def fetch_email(client, email_id) do
    request = %{
      "using" => ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
      "methodCalls" => [
        [
          "Email/get",
          %{
            "accountId" => client.account_id,
            "ids" => [email_id],
            "properties" => [
              "id",
              "subject",
              "from",
              "to",
              "receivedAt",
              "textBody",
              "htmlBody",
              "attachments",
              "threadId"
            ]
          },
          "a"
        ]
      ]
    }

    case make_request(client, request) do
      {:ok, %{"list" => [email | _]}} -> {:ok, email}
      {:ok, %{"list" => []}} -> {:error, "Email not found"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches the content of a blob by its ID.

  ## Parameters
    - client: The JMAP client struct
    - blob_id: The ID of the blob to fetch
    - type: The expected content type (optional)
      - "text/html" or "text/plain" will return a string
      - "application/octet-stream" or other types will return binary

  ## Returns
    * `{:ok, content}` - on success
      - For text types: {:ok, string}
      - For binary types: {:ok, binary}
    * `{:error, reason}` - on failure

  ## Examples
      iex> Jmap.Client.fetch_blob(client, "blob123", "text/html")
      {:ok, "<html>...</html>"}
      iex> Jmap.Client.fetch_blob(client, "blob123", "application/octet-stream")
      {:ok, <<...>>}
  """
  def fetch_blob(client, blob_id, type \\ "application/octet-stream") do
    # Replace placeholders in the download URL from the session response
    download_url =
      client.download_url
      |> String.replace("{accountId}", client.account_id)
      |> String.replace("{blobId}", blob_id)
      |> String.replace("{name}", "content")
      |> String.replace("{type}", type)

    headers = [
      {"Authorization", "Bearer #{client.api_token}"}
    ]

    http_client = get_http_client()

    case http_client.get(download_url, headers: headers) do
      {:ok, %{status: 200, body: content}} ->
        case type do
          "text/html" -> {:ok, content |> to_string()}
          "text/plain" -> {:ok, content |> to_string()}
          _ -> {:ok, content}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to fetch blob with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches a thread by its ID.

  ## Parameters
    - client: The JMAP client struct
    - thread_id: The ID of the thread to fetch

  ## Returns
    * `{:ok, thread}` - on success, containing thread ID and associated email IDs
    * `{:error, reason}` - on failure

  ## Examples
      iex> Jmap.Client.fetch_thread(client, "thread123")
      {:ok, %Jmap.Thread{id: "thread123", emailIds: ["email1", "email2"]}}
  """
  def fetch_thread(client, thread_id) do
    request = %{
      "using" => ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
      "methodCalls" => [
        [
          "Thread/get",
          %{
            "accountId" => client.account_id,
            "ids" => [thread_id]
          },
          "a"
        ]
      ]
    }

    case make_request(client, request) do
      {:ok, %{"list" => [thread | _]}} ->
        {:ok,
         %Jmap.Thread{
           id: thread["id"],
           emailIds: thread["emailIds"]
         }}

      {:ok, %{"list" => []}} ->
        {:error, "Thread not found"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp authenticate(client) do
    headers = [{"Authorization", "Bearer #{client.api_token}"}]

    http_client = get_http_client()

    case http_client.get(client.api_url, headers: headers) do
      {:ok, %{status: 200, body: session}} ->
        # Get the first account ID from primaryAccounts
        account_id = session["primaryAccounts"]["urn:ietf:params:jmap:mail"]

        # Get the account details
        account = get_in(session, ["accounts", account_id])

        if is_nil(account) do
          {:error, "Account not found in session response"}
        else
          with {:ok, mailboxes} <-
                 fetch_mailboxes(session["apiUrl"], client.api_token, account_id),
               {:ok, inbox_id} <- find_mailbox_id(mailboxes, "inbox"),
               {:ok, archive_id} <- find_mailbox_id(mailboxes, "archive") do
            {:ok,
             %{
               client
               | session_url: session["apiUrl"],
                 account_id: account_id,
                 inbox_id: inbox_id,
                 archive_id: archive_id,
                 download_url: session["downloadUrl"]
             }}
          else
            {:error, reason} -> {:error, reason}
          end
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "Authentication failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Authentication request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_mailboxes(api_url, api_token, account_id) do
    request = %{
      "using" => ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
      "methodCalls" => [
        [
          "Mailbox/get",
          %{
            "accountId" => account_id
          },
          "a"
        ]
      ]
    }

    headers = [
      {"Authorization", "Bearer #{api_token}"},
      {"Content-Type", "application/json"}
    ]

    http_client = get_http_client()

    case http_client.post(api_url, request, headers: headers) do
      {:ok, %{status: 200, body: %{"methodResponses" => [["Mailbox/get", result, "a"]]}}} ->
        {:ok, result["list"]}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to fetch mailboxes with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to fetch mailboxes: #{inspect(reason)}"}
    end
  end

  defp find_mailbox_id(mailboxes, role) do
    case mailboxes do
      nil ->
        {:error, "No mailboxes found in response"}

      mailboxes when is_list(mailboxes) ->
        case Enum.find(mailboxes, fn mailbox -> mailbox["role"] == role end) do
          nil -> {:error, "No mailbox found with role: #{role}"}
          mailbox -> {:ok, mailbox["id"]}
        end

      _ ->
        {:error, "Invalid mailboxes format in response"}
    end
  end

  defp make_request(client, request) do
    headers = [
      {"Authorization", "Bearer #{client.api_token}"},
      {"Content-Type", "application/json"}
    ]

    http_client = get_http_client()

    case http_client.post(client.session_url, request, headers: headers) do
      {:ok, %{status: 200, body: %{"methodResponses" => [[_method_name, result, _id]]}}} ->
        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        {:error, "Request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_http_client do
    Application.get_env(:jmap, :http_client) ||
      if Code.ensure_loaded?(Req) do
        Jmap.HttpClient.Req
      else
        Jmap.HttpClient.Web
      end
  end
end
