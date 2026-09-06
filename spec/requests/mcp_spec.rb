# frozen_string_literal: true

describe 'MCP endpoint' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:token) { author.mcp_tokens.create!(name: 'test').token }

  before do
    create(:account_config, account:, key: AccountConfig::ENABLE_MCP_KEY, value: true)
  end

  describe 'GET /mcp' do
    # The Streamable HTTP transport lets a client open a server->client SSE
    # stream with a GET, and requires the server to answer either with
    # `Content-Type: text/event-stream` or 405. We have no stream, so it is 405.
    #
    # This used to answer 200 with an empty body, which a client reads as a
    # stream that opened and then ended immediately, so it reconnects at once
    # and never stops. That held ~1.5 req/sec against a production instance.
    it 'refuses the SSE stream with 405 rather than an empty 200' do
      get '/mcp', headers: { Authorization: "Bearer #{token}", Accept: 'text/event-stream' }

      expect(response).to have_http_status(:method_not_allowed)
    end

    it 'still authenticates before answering' do
      get '/mcp', headers: { Accept: 'text/event-stream' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'HEAD /mcp' do
    # Rails routes HEAD through the GET handler, but `request.get?` is false for
    # it. Guarding on `get?` would let a HEAD reach `head :ok` and reopen exactly
    # the reconnect loop this endpoint was fixed for, on a different verb.
    it 'is refused like a GET' do
      head '/mcp', headers: { Authorization: "Bearer #{token}" }

      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  describe 'POST /mcp' do
    it 'is unaffected by the guard' do
      post '/mcp', headers: { Authorization: "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
    end
  end
end
