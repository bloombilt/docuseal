# frozen_string_literal: true

class McpController < ActionController::API
  before_action :authenticate_user!
  before_action :verify_mcp_enabled!

  before_action do
    authorize!(:manage, :mcp)
  end

  def call
    # A GET is a client opening the optional server->client SSE stream. We don't
    # offer one, and the Streamable HTTP spec is explicit that the only two legal
    # answers are `Content-Type: text/event-stream` or 405 Method Not Allowed.
    #
    # `head :ok` reads to a client as "stream opened", it then sees EOF straight
    # away and reconnects, forever. Claude Code held ~1.5 req/sec against this
    # endpoint for as long as it was configured, which kept the whole service
    # awake and defeated Railway's app sleeping.
    #
    # Keyed off `post?` rather than `get?` because Rails routes HEAD through the
    # GET handler while `request.get?` is false for it, so a HEAD would slip past
    # and reach `head :ok` again. Only POST carries a JSON-RPC message.
    return head :method_not_allowed unless request.post?

    return head :ok if request.raw_post.blank?

    body = JSON.parse(request.raw_post)

    result = Mcp::HandleRequest.call(body, current_user, current_ability)

    if result
      render json: result
    else
      head :accepted
    end
  rescue CanCan::AccessDenied
    render json: { jsonrpc: '2.0', id: nil, error: { code: -32_603, message: 'Forbidden' } }, status: :forbidden
  rescue JSON::ParserError
    render json: { jsonrpc: '2.0', id: nil, error: { code: -32_700, message: 'Parse error' } }, status: :bad_request
  end

  private

  def authenticate_user!
    render json: { error: 'Not authenticated' }, status: :unauthorized unless current_user
  end

  def verify_mcp_enabled!
    return if Docuseal.multitenant?

    return if AccountConfig.exists?(account_id: current_user.account_id,
                                    key: AccountConfig::ENABLE_MCP_KEY,
                                    value: true)

    render json: { error: 'MCP is disabled' }, status: :forbidden
  end

  def current_user
    @current_user ||= user_from_api_key
  end

  def user_from_api_key
    token = request.headers['Authorization'].to_s[/\ABearer\s+(.+)\z/, 1]

    return if token.blank?

    sha256 = Digest::SHA256.hexdigest(token)

    User.joins(:mcp_tokens).active.find_by(mcp_tokens: { sha256:, archived_at: nil })
  end
end
