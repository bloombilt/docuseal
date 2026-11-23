# frozen_string_literal: true

# A signer who is also logged into another Bloombilt app carries Clerk cookies
# for .bloombilt.com. Once the __session token is stale, Clerk's middleware
# answers with a 307 handshake redirect, which breaks the signing form's
# fetch calls. A client_uat cookie without a session token on a document
# request triggers the same handshake without needing a signed JWT.
describe 'Clerk middleware on signing routes' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:headers) { { 'Sec-Fetch-Dest' => 'document', 'Accept' => 'text/html', 'Cookie' => '__client_uat=1700000000' } }

  before do
    allow(Clerk.configuration).to receive_messages(
      secret_key: 'sk_live_dummy',
      publishable_key: "pk_live_#{Base64.strict_encode64('clerk.example.com$')}"
    )
  end

  it 'still runs on admin pages' do
    get '/templates', headers: headers

    expect(response).to have_http_status(:temporary_redirect)
    expect(response.location).to include('clerk.example.com/v1/client/handshake')
  end

  it 'skips the signing form' do
    get "/s/#{submission.submitters.first.slug}", headers: headers

    expect(response).to have_http_status(:ok)
  end

  it 'skips the form view and attachment endpoints' do
    post '/api/submitter_form_views', params: { submitter_slug: submission.submitters.first.slug }, headers: headers

    expect(response).not_to have_http_status(:temporary_redirect)
  end
end
