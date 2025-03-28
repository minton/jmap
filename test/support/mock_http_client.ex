defmodule Jmap.Support.MockHttpClient do
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
             "accounts" => %{
               "mock-account-id" => %{
                 "name" => "test@example.com",
                 "isPersonal" => true,
                 "isReadOnly" => false,
                 "accountCapabilities" => %{
                   "urn:ietf:params:jmap:mail" => %{
                     "maxMailboxesPerEmail" => 1,
                     "maxMailboxDepth" => 10,
                     "maxSizeMailboxName" => 200,
                     "maxSizeAttachmentsPerEmail" => 50_000_000,
                     "emailQuerySortOptions" => ["receivedAt", "subject", "size", "from", "to"],
                     "mayCreateTopLevelMailbox" => true
                   }
                 }
               }
             },
             "capabilities" => %{
               "urn:ietf:params:jmap:core" => %{
                 "maxSizeUpload" => 50_000_000,
                 "maxConcurrentUpload" => 4,
                 "maxSizeRequest" => 10_000_000,
                 "maxConcurrentRequests" => 4,
                 "maxCallsInRequest" => 16,
                 "maxObjectsInGet" => 500,
                 "maxObjectsInSet" => 500,
                 "collationAlgorithms" => [
                   "i;ascii-numeric",
                   "i;ascii-casemap",
                   "i;unicode-casemap"
                 ]
               },
               "urn:ietf:params:jmap:mail" => %{
                 "maxMailboxesPerEmail" => 1,
                 "maxMailboxDepth" => 10,
                 "maxSizeMailboxName" => 200,
                 "maxSizeAttachmentsPerEmail" => 50_000_000,
                 "emailQuerySortOptions" => ["receivedAt", "subject", "size", "from", "to"],
                 "mayCreateTopLevelMailbox" => true
               }
             },
             "username" => "test@example.com",
             "downloadUrl" =>
               "https://api.fastmail.com/jmap/download/{accountId}/{blobId}/{name}",
             "uploadUrl" => "https://api.fastmail.com/jmap/upload/{accountId}/",
             "eventSourceUrl" => "https://api.fastmail.com/jmap/eventsource/",
             "state" => "test-state"
           }
         }}

      _ ->
        {:error, "Unexpected URL: #{url}"}
    end
  end

  @impl true
  def post(url, body, _opts \\ []) do
    case url do
      "https://api.fastmail.com/jmap/api/" ->
        handle_jmap_request(body)

      _ ->
        {:error, "Unexpected URL: #{url}"}
    end
  end

  defp handle_jmap_request(%{"methodCalls" => method_calls}) do
    responses =
      Enum.map(method_calls, fn [method, _args, call_id] ->
        case method do
          "Mailbox/get" ->
            [
              "Mailbox/get",
              %{
                "accountId" => "mock-account-id",
                "list" => [
                  %{
                    "id" => "inbox-id",
                    "name" => "INBOX",
                    "parentId" => nil,
                    "role" => "inbox",
                    "sortOrder" => 100,
                    "totalEmails" => 0,
                    "unreadEmails" => 0,
                    "totalThreads" => 0,
                    "unreadThreads" => 0,
                    "myRights" => %{
                      "mayReadItems" => true,
                      "mayAddItems" => true,
                      "mayRemoveItems" => true,
                      "maySetSeen" => true,
                      "maySetKeywords" => true,
                      "mayCreateChild" => true,
                      "mayRename" => true,
                      "mayDelete" => true,
                      "maySubmit" => true
                    },
                    "isSubscribed" => true
                  },
                  %{
                    "id" => "archive-id",
                    "name" => "Archive",
                    "parentId" => nil,
                    "role" => "archive",
                    "sortOrder" => 200,
                    "totalEmails" => 0,
                    "unreadEmails" => 0,
                    "totalThreads" => 0,
                    "unreadThreads" => 0,
                    "myRights" => %{
                      "mayReadItems" => true,
                      "mayAddItems" => true,
                      "mayRemoveItems" => true,
                      "maySetSeen" => true,
                      "maySetKeywords" => true,
                      "mayCreateChild" => true,
                      "mayRename" => true,
                      "mayDelete" => true,
                      "maySubmit" => true
                    },
                    "isSubscribed" => true
                  }
                ],
                "notFound" => []
              },
              call_id
            ]

          "Email/query" ->
            [
              "Email/query",
              %{
                "accountId" => "mock-account-id",
                "queryState" => "test-state",
                "canCalculateChanges" => true,
                "position" => 0,
                "total" => 2,
                "ids" => ["email-1", "email-2"]
              },
              call_id
            ]

          "Email/set" ->
            [
              "Email/set",
              %{
                "updated" => ["email-1"]
              },
              "a"
            ]
        end
      end)

    {:ok,
     %{
       status: 200,
       body: %{
         "sessionState" => "test-state",
         "methodResponses" => responses
       }
     }}
  end
end
