defmodule Jmap.ClientTest do
  use ExUnit.Case

  setup do
    # Set up test configuration
    Application.put_env(:jmap, :api_token, "test-token")
    Application.put_env(:jmap, :provider, :fastmail)
    Application.put_env(:jmap, :http_client, Jmap.Support.MockHttpClient)

    :ok
  end

  describe "new/0" do
    test "creates a client with configuration" do
      assert {:ok, client} = Jmap.new()
      assert client.api_token == "test-token"
      assert client.provider == :fastmail
      assert client.session_url == "https://api.fastmail.com/jmap/api/"
      assert client.account_id == "mock-account-id"
      assert client.inbox_id == "inbox-id"
      assert client.archive_id == "archive-id"
    end

    test "returns error when api_token is missing" do
      Application.delete_env(:jmap, :api_token)
      assert {:error, "API token not configured"} = Jmap.new()
    end

    test "returns error when provider is missing" do
      Application.delete_env(:jmap, :provider)
      assert {:error, "Provider not configured"} = Jmap.new()
    end
  end

  describe "new/3" do
    test "creates a client with explicit configuration" do
      assert {:ok, client} = Jmap.new("test-token", :fastmail)
      assert client.api_token == "test-token"
      assert client.provider == :fastmail
    end

    test "returns error when provider is not an atom" do
      assert {:error, "Invalid provider: \"fastmail\". Expected an atom."} =
               Jmap.new("test-token", "fastmail")
    end
  end

  describe "fetch_emails/2" do
    setup do
      {:ok, client} = Jmap.new()
      {:ok, client: client}
    end

    test "fetches emails from inbox", %{client: client} do
      assert {:ok, %{"ids" => ["email-1", "email-2"]}} = Jmap.fetch_emails(client)
    end

    test "handles error responses", %{client: client} do
      # Override the mock for this test
      defmodule TestHttpClient1 do
        @behaviour Jmap.HttpClient

        @impl true
        def get(url, _opts \\ []) do
          case url do
            "https://api.fastmail.com/jmap/session" ->
              {:ok,
               %{
                 status: 200,
                 body: %{
                   "apiUrl" => "https://api.fastmail.com/jmap/api/",
                   "accessToken" => "mock-access-token",
                   "primaryAccounts" => %{
                     "urn:ietf:params:jmap:mail" => "mock-account-id"
                   },
                   "mailboxes" => [
                     %{"id" => "inbox-id", "role" => "inbox"},
                     %{"id" => "archive-id", "role" => "archive"}
                   ]
                 }
               }}

            _ ->
              {:error, "Unexpected URL: #{url}"}
          end
        end

        @impl true
        def post(_url, _body, _opts \\ []) do
          {:error, "Network error"}
        end
      end

      Application.put_env(:jmap, :http_client, TestHttpClient1)
      assert {:error, "Network error"} = Jmap.fetch_emails(client)
    end
  end

  describe "archive_email/2" do
    setup do
      {:ok, client} = Jmap.new()
      {:ok, client: client}
    end

    test "archives an email", %{client: client} do
      {:ok, result} = Jmap.archive_email(client, "email-1")
      assert result["updated"] == ["email-1"]
    end

    test "handles error responses", %{client: client} do
      # Override the mock for this test
      defmodule TestHttpClient2 do
        @behaviour Jmap.HttpClient

        @impl true
        def get(url, _opts \\ []) do
          case url do
            "https://api.fastmail.com/jmap/session" ->
              {:ok,
               %{
                 status: 200,
                 body: %{
                   "apiUrl" => "https://api.fastmail.com/jmap/api/",
                   "accessToken" => "mock-access-token",
                   "primaryAccounts" => %{
                     "urn:ietf:params:jmap:mail" => "mock-account-id"
                   },
                   "mailboxes" => [
                     %{"id" => "inbox-id", "role" => "inbox"},
                     %{"id" => "archive-id", "role" => "archive"}
                   ]
                 }
               }}

            _ ->
              {:error, "Unexpected URL: #{url}"}
          end
        end

        @impl true
        def post(_url, _body, _opts \\ []) do
          {:error, "Network error"}
        end
      end

      Application.put_env(:jmap, :http_client, TestHttpClient2)
      assert {:error, "Network error"} = Jmap.archive_email(client, "email-1")
    end
  end
end
